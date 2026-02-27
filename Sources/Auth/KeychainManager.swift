import Foundation
@preconcurrency import KeychainAccess

final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()

    private let keychain: Keychain
    private let defaults = UserDefaults.standard

    private init() {
        self.keychain = Keychain(service: "com.workwidget.app")
            .accessibility(.afterFirstUnlock)
    }

    // MARK: - OAuth Tokens

    func saveTokens(_ tokens: OAuthTokens, for service: ServiceType) throws {
        let data = try JSONEncoder().encode(tokens)
        try keychain.set(data, key: tokenKey(for: service))
    }

    func getTokens(for service: ServiceType) throws -> OAuthTokens? {
        guard let data = try keychain.getData(tokenKey(for: service)) else {
            return nil
        }
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    func deleteTokens(for service: ServiceType) throws {
        try keychain.remove(tokenKey(for: service))
    }

    func hasTokens(for service: ServiceType) -> Bool {
        (try? getTokens(for: service)) != nil
    }

    // MARK: - GitHub Multi-Account Tokens

    func saveGitHubTokens(_ tokens: OAuthTokens, for login: String) throws {
        let normalized = login.lowercased()
        let data = try JSONEncoder().encode(tokens)
        try keychain.set(data, key: githubTokenKey(for: normalized))

        var logins = listGitHubAccountLogins()
        if !logins.contains(normalized) {
            logins.append(normalized)
            logins.sort()
            defaults.set(logins, forKey: AppDefaultsKeys.githubAccountLogins)
        }
    }

    func getGitHubTokens(for login: String) throws -> OAuthTokens? {
        let normalized = login.lowercased()
        guard let data = try keychain.getData(githubTokenKey(for: normalized)) else {
            return nil
        }
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    func deleteGitHubTokens(for login: String) throws {
        let normalized = login.lowercased()
        try keychain.remove(githubTokenKey(for: normalized))

        var logins = listGitHubAccountLogins()
        logins.removeAll { $0 == normalized }
        defaults.set(logins, forKey: AppDefaultsKeys.githubAccountLogins)
    }

    func clearAllGitHubAccountTokens() throws {
        let logins = listGitHubAccountLogins()
        for login in logins {
            try? keychain.remove(githubTokenKey(for: login))
        }
        defaults.removeObject(forKey: AppDefaultsKeys.githubAccountLogins)
        defaults.removeObject(forKey: AppDefaultsKeys.githubActiveAccountLogin)
    }

    func listGitHubAccountLogins() -> [String] {
        defaults.stringArray(forKey: AppDefaultsKeys.githubAccountLogins) ?? []
    }

    // MARK: - Private

    private func tokenKey(for service: ServiceType) -> String {
        "tokens-\(service.rawValue)"
    }

    private func githubTokenKey(for login: String) -> String {
        "tokens-github-\(login)"
    }
}
