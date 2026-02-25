import Foundation

final class NotionService: NotificationService, Sendable {
    let serviceType: ServiceType = .notion

    private let httpClient = HTTPClient.shared
    private let keychain = KeychainManager.shared
    private let oauthManager: OAuthManager
    private let baseURL = "https://api.notion.com/v1"

    init(oauthManager: OAuthManager) {
        self.oauthManager = oauthManager
    }

    func fetchNotifications() async throws -> [WorkNotification] {
        let token = try await getValidToken()

        // Search recently edited pages
        let url = URL(string: "\(baseURL)/search")!
        let body = try JSONEncoder().encode(NotionSearchRequest(
            sort: NotionSearchRequest.Sort(direction: "descending", timestamp: "last_edited_time"),
            page_size: 10
        ))

        let response: NotionSearchResponse = try await httpClient.post(
            url: url,
            bearerToken: token,
            body: body,
            additionalHeaders: ["Notion-Version": "2022-06-28"]
        )

        return response.results
            .filter { $0.object == "page" }
            .prefix(10)
            .map { object in
                WorkNotification(
                    id: "notion-\(object.id)",
                    service: .notion,
                    title: object.displayTitle,
                    subtitle: formatRelativeTime(object.editedDate),
                    body: "",
                    timestamp: object.editedDate,
                    url: object.browseURL,
                    isPinned: false,
                    iconName: object.iconName,
                    priority: .normal
                )
            }
    }

    private func getValidToken() async throws -> String {
        guard let tokens = try keychain.getTokens(for: .notion) else {
            throw ServiceError.notAuthenticated
        }
        // Notion OAuth tokens don't expire
        return tokens.accessToken
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

// MARK: - Request Models

private struct NotionSearchRequest: Encodable {
    let sort: Sort
    let page_size: Int

    struct Sort: Encodable {
        let direction: String
        let timestamp: String
    }
}
