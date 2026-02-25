import Foundation

/// Protocol that all notification-providing services implement.
protocol NotificationService: Sendable {
    var serviceType: ServiceType { get }
    func fetchNotifications() async throws -> [WorkNotification]
}

enum ServiceError: LocalizedError {
    case notAuthenticated
    case accessDenied
    case calendarAccessDenied
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Not authenticated - please connect in Settings"
        case .accessDenied: "Access denied"
        case .calendarAccessDenied: "Open System Settings to grant calendar access"
        case .apiError(let msg): msg
        }
    }
}
