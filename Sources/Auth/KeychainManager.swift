import Foundation
@preconcurrency import KeychainAccess

final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()

    private let keychain: Keychain

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

    // MARK: - Private

    private func tokenKey(for service: ServiceType) -> String {
        "tokens-\(service.rawValue)"
    }
}
