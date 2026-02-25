import Foundation

enum NotificationPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct WorkNotification: Identifiable, Equatable, Sendable {
    let id: String
    let service: ServiceType
    let title: String
    let subtitle: String
    let body: String
    let timestamp: Date
    let url: URL?
    var isPinned: Bool
    let iconName: String
    let priority: NotificationPriority

    static func == (lhs: WorkNotification, rhs: WorkNotification) -> Bool {
        lhs.id == rhs.id && lhs.isPinned == rhs.isPinned
    }
}
