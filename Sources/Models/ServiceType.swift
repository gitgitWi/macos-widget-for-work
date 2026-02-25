import Foundation

enum ServiceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case teams
    case github
    case notion
    case eventKit
    case googleCalendar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teams: "Microsoft Teams"
        case .github: "GitHub"
        case .notion: "Notion"
        case .eventKit: "macOS Calendar"
        case .googleCalendar: "Google Calendar"
        }
    }

    var systemImage: String {
        switch self {
        case .teams: "bubble.left.and.bubble.right"
        case .github: "arrow.triangle.branch"
        case .notion: "doc.text"
        case .eventKit: "calendar"
        case .googleCalendar: "calendar.badge.clock"
        }
    }

    var isCalendar: Bool {
        switch self {
        case .eventKit, .googleCalendar: true
        case .teams, .github, .notion: false
        }
    }

    var accentColorName: String {
        switch self {
        case .teams: "purple"
        case .github: "primary"
        case .notion: "primary"
        case .eventKit: "red"
        case .googleCalendar: "blue"
        }
    }
}
