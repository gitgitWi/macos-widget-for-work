import Foundation

// MARK: - Notion Search API Response

struct NotionSearchResponse: Decodable, Sendable {
    let results: [NotionObject]
    let has_more: Bool
    let next_cursor: String?
}

struct NotionObject: Decodable, Sendable {
    let id: String
    let object: String // "page" or "database"
    let created_time: String
    let last_edited_time: String
    let url: String?
    let properties: [String: NotionProperty]?
    let parent: NotionParent?

    // For databases
    let title: [NotionRichText]?

    struct NotionParent: Decodable, Sendable {
        let type: String?
        let database_id: String?
        let page_id: String?
        let workspace: Bool?
    }

    var displayTitle: String {
        // Try page title from properties
        if let titleProp = properties?.values.first(where: { $0.type == "title" }),
           let titleTexts = titleProp.title,
           let first = titleTexts.first
        {
            return first.plain_text ?? "Untitled"
        }
        // Try database title
        if let titleTexts = title, let first = titleTexts.first {
            return first.plain_text ?? "Untitled"
        }
        return "Untitled"
    }

    var editedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: last_edited_time) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: last_edited_time) ?? Date()
    }

    var browseURL: URL? {
        url.flatMap { URL(string: $0) }
    }

    var iconName: String {
        switch object {
        case "database": return "tablecells"
        case "page": return "doc.text"
        default: return "doc"
        }
    }
}

struct NotionProperty: Decodable, Sendable {
    let id: String?
    let type: String?
    let title: [NotionRichText]?
}

struct NotionRichText: Decodable, Sendable {
    let type: String?
    let plain_text: String?
}
