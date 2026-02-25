import Foundation

final class TeamsService: NotificationService, Sendable {
    let serviceType: ServiceType = .teams

    private let httpClient = HTTPClient.shared
    private let keychain = KeychainManager.shared
    private let oauthManager: OAuthManager
    private let graphURL = "https://graph.microsoft.com/v1.0"

    init(oauthManager: OAuthManager) {
        self.oauthManager = oauthManager
    }

    func fetchNotifications() async throws -> [WorkNotification] {
        let token = try await getValidToken()

        // Fetch recent chats
        let chatsURL = URL(string: "\(graphURL)/me/chats?$top=10&$orderby=lastMessagePreview/createdDateTime desc")!
        let chats: GraphResponse<GraphChat> = try await httpClient.get(
            url: chatsURL,
            bearerToken: token
        )

        var notifications: [WorkNotification] = []

        // Fetch last message from each chat
        for chat in chats.value.prefix(7) {
            let messagesURL = URL(string: "\(graphURL)/me/chats/\(chat.id)/messages?$top=1&$orderby=createdDateTime desc")!
            do {
                let messages: GraphResponse<GraphChatMessage> = try await httpClient.get(
                    url: messagesURL,
                    bearerToken: token
                )
                if let message = messages.value.first, message.messageType != "systemEventMessage" {
                    notifications.append(
                        WorkNotification(
                            id: "teams-\(chat.id)-\(message.id)",
                            service: .teams,
                            title: chat.displayTopic,
                            subtitle: message.senderName,
                            body: String(message.plainTextBody.prefix(100)),
                            timestamp: message.parsedDate,
                            url: message.browseURL,
                            isPinned: false,
                            iconName: "bubble.left.and.bubble.right",
                            priority: .normal
                        )
                    )
                }
            } catch {
                // Skip chats where we can't fetch messages
                continue
            }
        }

        return notifications.sorted { $0.timestamp > $1.timestamp }
    }

    private func getValidToken() async throws -> String {
        guard let tokens = try keychain.getTokens(for: .teams) else {
            throw ServiceError.notAuthenticated
        }

        // Check expiry and refresh if needed
        if let expiresAt = tokens.expiresAt, expiresAt < Date().addingTimeInterval(300) {
            let clientID = ProcessInfo.processInfo.environment["MICROSOFT_CLIENT_ID"] ?? ""
            let config = OAuthConfig.microsoft(clientID: clientID)
            return try await oauthManager.refreshTokenIfNeeded(for: .teams, config: config)
        }

        return tokens.accessToken
    }
}
