import Foundation

final class GitHubService: NotificationService, Sendable {
    let serviceType: ServiceType = .github

    private let httpClient = HTTPClient.shared
    private let keychain = KeychainManager.shared
    private let oauthManager: OAuthManager
    private let baseURL = "https://api.github.com"

    init(oauthManager: OAuthManager) {
        self.oauthManager = oauthManager
    }

    func fetchNotifications() async throws -> [WorkNotification] {
        let token = try await getValidToken()

        let url = URL(string: "\(baseURL)/notifications?participating=true&per_page=20")!
        let notifications: [GitHubNotification] = try await httpClient.get(
            url: url,
            bearerToken: token
        )

        return notifications.prefix(10).map { notification in
            WorkNotification(
                id: "gh-\(notification.id)",
                service: .github,
                title: notification.subject.title,
                subtitle: notification.repository.full_name,
                body: notification.reason.replacingOccurrences(of: "_", with: " ").capitalized,
                timestamp: notification.parsedDate,
                url: notification.htmlURL,
                isPinned: false,
                iconName: notification.iconName,
                priority: notification.priority
            )
        }
    }

    private func getValidToken() async throws -> String {
        guard let tokens = try keychain.getTokens(for: .github) else {
            throw ServiceError.notAuthenticated
        }
        // GitHub tokens don't expire (PAT-style from OAuth), return as-is
        return tokens.accessToken
    }
}
