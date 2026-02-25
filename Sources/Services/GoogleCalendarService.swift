import Foundation

final class GoogleCalendarService: NotificationService, Sendable {
    let serviceType: ServiceType = .googleCalendar

    private let httpClient = HTTPClient.shared
    private let keychain = KeychainManager.shared
    private let oauthManager: OAuthManager
    private let baseURL = "https://www.googleapis.com/calendar/v3"

    init(oauthManager: OAuthManager) {
        self.oauthManager = oauthManager
    }

    func fetchNotifications() async throws -> [WorkNotification] {
        let token = try await getValidToken()

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now)!

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let timeMin = formatter.string(from: now)
        let timeMax = formatter.string(from: endDate)

        let urlString = "\(baseURL)/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime&maxResults=10"

        guard let url = URL(string: urlString) else {
            throw ServiceError.apiError("Invalid URL")
        }

        let eventList: GoogleCalendarEventList = try await httpClient.get(
            url: url,
            bearerToken: token
        )

        return (eventList.items ?? [])
            .filter { $0.status != "cancelled" }
            .prefix(10)
            .map { event in
                WorkNotification(
                    id: "gcal-\(event.id)",
                    service: .googleCalendar,
                    title: event.eventTitle,
                    subtitle: event.timeRangeString,
                    body: meetingBody(for: event),
                    timestamp: event.startDate,
                    url: event.meetingURL ?? event.browseURL,
                    isPinned: false,
                    iconName: "calendar.badge.clock",
                    priority: priorityForEvent(event, now: now)
                )
            }
    }

    private func getValidToken() async throws -> String {
        guard let tokens = try keychain.getTokens(for: .googleCalendar) else {
            throw ServiceError.notAuthenticated
        }

        // Check expiry and refresh if needed
        if let expiresAt = tokens.expiresAt, expiresAt < Date().addingTimeInterval(300) {
            let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
            let config = OAuthConfig.google(clientID: clientID)
            return try await oauthManager.refreshTokenIfNeeded(for: .googleCalendar, config: config)
        }

        return tokens.accessToken
    }

    private func meetingBody(for event: GoogleCalendarEvent) -> String {
        if event.meetingURL != nil { return "Online Meeting" }
        return ""
    }

    private func priorityForEvent(_ event: GoogleCalendarEvent, now: Date) -> NotificationPriority {
        let minutesUntilStart = event.startDate.timeIntervalSince(now) / 60

        if minutesUntilStart <= 15 { return .high }
        if minutesUntilStart <= 60 { return .normal }
        return .low
    }
}
