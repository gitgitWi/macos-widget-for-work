import Foundation

// MARK: - Microsoft Graph Chat Messages API

struct GraphResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let value: [T]
    // let `@odata.nextLink`: String?  // for pagination
}

struct GraphChatMessage: Decodable, Sendable {
    let id: String
    let createdDateTime: String
    let messageType: String?
    let body: GraphMessageBody?
    let from: GraphFrom?
    let chatId: String?
    let channelIdentity: GraphChannelIdentity?
    let webUrl: String?

    struct GraphMessageBody: Decodable, Sendable {
        let contentType: String? // "text" or "html"
        let content: String?
    }

    struct GraphFrom: Decodable, Sendable {
        let user: GraphUser?
    }

    struct GraphUser: Decodable, Sendable {
        let displayName: String?
        let id: String?
    }

    struct GraphChannelIdentity: Decodable, Sendable {
        let teamId: String?
        let channelId: String?
    }

    var senderName: String {
        from?.user?.displayName ?? "Unknown"
    }

    var plainTextBody: String {
        guard let content = body?.content else { return "" }
        if body?.contentType == "html" {
            // Strip HTML tags for preview
            return content
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdDateTime) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdDateTime) ?? Date()
    }

    var browseURL: URL? {
        webUrl.flatMap { URL(string: $0) }
    }
}

// MARK: - Microsoft Graph Chats

struct GraphChat: Decodable, Sendable {
    let id: String
    let topic: String?
    let chatType: String? // "oneOnOne", "group", "meeting"

    var displayTopic: String {
        topic ?? (chatType == "oneOnOne" ? "Direct Message" : "Group Chat")
    }
}
