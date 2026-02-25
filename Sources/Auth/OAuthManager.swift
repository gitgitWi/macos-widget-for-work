import AuthenticationServices
import CryptoKit
import Foundation

enum OAuthError: LocalizedError {
    case noCallback
    case noAuthCode
    case tokenExchangeFailed(String)
    case noPresentationAnchor
    case unsupportedService

    var errorDescription: String? {
        switch self {
        case .noCallback: "No callback received from authentication"
        case .noAuthCode: "No authorization code in callback"
        case .tokenExchangeFailed(let msg): "Token exchange failed: \(msg)"
        case .noPresentationAnchor: "No window available for authentication"
        case .unsupportedService: "This service does not use OAuth"
        }
    }
}

@MainActor
final class OAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var presentationAnchor: NSWindow?
    private let keychain = KeychainManager.shared

    func setPresentationAnchor(_ window: NSWindow) {
        self.presentationAnchor = window
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            presentationAnchor ?? NSApp.windows.first ?? NSWindow()
        }
    }

    // MARK: - Public API

    func authenticate(service: ServiceType, config: OAuthConfig) async throws {
        let tokens: OAuthTokens

        switch service {
        case .github:
            tokens = try await performOAuth(config: config, isGitHub: true)
        case .teams:
            tokens = try await performOAuth(config: config, usePKCE: true)
        case .notion:
            tokens = try await performNotionOAuth(config: config)
        case .googleCalendar:
            tokens = try await performOAuth(config: config, usePKCE: true)
        case .eventKit:
            throw OAuthError.unsupportedService
        }

        try keychain.saveTokens(tokens, for: service)
    }

    func disconnect(service: ServiceType) throws {
        try keychain.deleteTokens(for: service)
    }

    // MARK: - Standard OAuth (GitHub, Microsoft, Google)

    private func performOAuth(
        config: OAuthConfig,
        usePKCE: Bool = false,
        isGitHub: Bool = false
    ) async throws -> OAuthTokens {
        let state = UUID().uuidString

        var codeVerifier: String?
        var urlString = "\(config.authorizeURL)"
            + "?client_id=\(config.clientID)"
            + "&redirect_uri=\(config.redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.redirectURI)"
            + "&state=\(state)"
            + "&response_type=code"

        if !config.scopes.isEmpty {
            let scopeParam = config.scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.scopes
            urlString += "&scope=\(scopeParam)"
        }

        if usePKCE {
            let verifier = generateCodeVerifier()
            codeVerifier = verifier
            let challenge = generateCodeChallenge(from: verifier)
            urlString += "&code_challenge=\(challenge)&code_challenge_method=S256"
        }

        guard let authURL = URL(string: urlString) else {
            throw OAuthError.tokenExchangeFailed("Invalid auth URL")
        }

        let callbackURL = try await startAuthSession(
            url: authURL,
            callbackScheme: config.callbackScheme
        )

        guard let code = extractQueryParam("code", from: callbackURL) else {
            throw OAuthError.noAuthCode
        }

        let returnedState = extractQueryParam("state", from: callbackURL)
        if let returnedState, returnedState != state {
            throw OAuthError.tokenExchangeFailed("State mismatch")
        }

        return try await exchangeCode(
            code,
            config: config,
            codeVerifier: codeVerifier,
            isGitHub: isGitHub
        )
    }

    // MARK: - Notion OAuth (uses Basic auth for token exchange)

    private func performNotionOAuth(config: OAuthConfig) async throws -> OAuthTokens {
        let state = UUID().uuidString

        let urlString = "\(config.authorizeURL)"
            + "?client_id=\(config.clientID)"
            + "&redirect_uri=\(config.redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.redirectURI)"
            + "&response_type=code"
            + "&owner=user"
            + "&state=\(state)"

        guard let authURL = URL(string: urlString) else {
            throw OAuthError.tokenExchangeFailed("Invalid auth URL")
        }

        let callbackURL = try await startAuthSession(
            url: authURL,
            callbackScheme: config.callbackScheme
        )

        guard let code = extractQueryParam("code", from: callbackURL) else {
            throw OAuthError.noAuthCode
        }

        // Notion uses Basic auth (client_id:client_secret) for token exchange
        let credentials = "\(config.clientID):\(config.clientSecret)"
        let base64 = Data(credentials.utf8).base64EncodedString()

        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        let tokenResponse = try JSONDecoder().decode(NotionTokenResponse.self, from: data)

        return OAuthTokens(
            accessToken: tokenResponse.access_token,
            refreshToken: nil,
            expiresAt: nil
        )
    }

    // MARK: - ASWebAuthenticationSession

    private func startAuthSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: OAuthError.noCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - Token Exchange

    private func exchangeCode(
        _ code: String,
        config: OAuthConfig,
        codeVerifier: String?,
        isGitHub: Bool
    ) async throws -> OAuthTokens {
        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"

        if isGitHub {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var body: [String: String] = [
                "client_id": config.clientID,
                "client_secret": config.clientSecret,
                "code": code,
            ]
            if !config.redirectURI.isEmpty {
                body["redirect_uri"] = config.redirectURI
            }
            request.httpBody = try JSONEncoder().encode(body)
        } else {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            var params = "client_id=\(config.clientID)"
                + "&code=\(code)"
                + "&redirect_uri=\(config.redirectURI)"
                + "&grant_type=authorization_code"

            if !config.clientSecret.isEmpty {
                params += "&client_secret=\(config.clientSecret)"
            }
            if let codeVerifier {
                params += "&code_verifier=\(codeVerifier)"
            }
            request.httpBody = params.data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        if isGitHub {
            let ghResponse = try JSONDecoder().decode(GitHubTokenResponse.self, from: data)
            guard !ghResponse.access_token.isEmpty else {
                throw OAuthError.tokenExchangeFailed(ghResponse.error ?? "empty token")
            }
            return OAuthTokens(
                accessToken: ghResponse.access_token,
                refreshToken: nil,
                expiresAt: nil
            )
        } else {
            let tokenResponse = try JSONDecoder().decode(StandardTokenResponse.self, from: data)
            return OAuthTokens(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token,
                expiresAt: tokenResponse.expires_in.map {
                    Date().addingTimeInterval(TimeInterval($0))
                }
            )
        }
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded(for service: ServiceType, config: OAuthConfig) async throws -> String {
        guard let tokens = try keychain.getTokens(for: service) else {
            throw OAuthError.tokenExchangeFailed("No tokens found")
        }

        // GitHub tokens don't expire
        if service == .github || service == .notion {
            return tokens.accessToken
        }

        // Check if token is still valid (with 5-minute buffer)
        if let expiresAt = tokens.expiresAt,
           expiresAt > Date().addingTimeInterval(300) {
            return tokens.accessToken
        }

        // Refresh token
        guard let refreshToken = tokens.refreshToken else {
            throw OAuthError.tokenExchangeFailed("No refresh token available")
        }

        var request = URLRequest(url: URL(string: config.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = "client_id=\(config.clientID)"
            + "&refresh_token=\(refreshToken)"
            + "&grant_type=refresh_token"

        request.httpBody = params.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        let tokenResponse = try JSONDecoder().decode(StandardTokenResponse.self, from: data)
        let newTokens = OAuthTokens(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? refreshToken,
            expiresAt: tokenResponse.expires_in.map {
                Date().addingTimeInterval(TimeInterval($0))
            }
        )
        try keychain.saveTokens(newTokens, for: service)
        return newTokens.accessToken
    }

    // MARK: - URL Helpers

    private func extractQueryParam(_ name: String, from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Token Response Models

private struct GitHubTokenResponse: Decodable {
    let access_token: String
    let token_type: String?
    let scope: String?
    let error: String?
}

private struct StandardTokenResponse: Decodable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
    let refresh_token: String?
    let scope: String?
}

private struct NotionTokenResponse: Decodable {
    let access_token: String
    let token_type: String?
    let workspace_id: String?
    let workspace_name: String?
}
