import EventKit
import Foundation

final class EventKitCalendarService: NotificationService, @unchecked Sendable {
    let serviceType: ServiceType = .eventKit

    private let eventStore = EKEventStore()
    private weak var settingsStore: SettingsStore?

    init(settingsStore: SettingsStore? = nil) {
        self.settingsStore = settingsStore
    }

    func fetchNotifications() async throws -> [WorkNotification] {
        // Check current authorization first
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .denied || status == .restricted {
            throw ServiceError.calendarAccessDenied
        }

        // Request calendar access (shows dialog only if not yet determined)
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw ServiceError.calendarAccessDenied
        }

        let now = Date()
        let lookaheadHours = settingsStore?.calendarLookaheadHours ?? 24
        let endDate = Calendar.current.date(byAdding: .hour, value: lookaheadHours, to: now)!

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        return events.prefix(10).map { event in
            let timeRange = formatTimeRange(start: event.startDate, end: event.endDate, isAllDay: event.isAllDay)
            let meetingInfo = extractMeetingInfo(from: event)

            return WorkNotification(
                id: "cal-\(event.eventIdentifier ?? UUID().uuidString)",
                service: .eventKit,
                title: event.title ?? "No Title",
                subtitle: timeRange,
                body: meetingInfo,
                timestamp: event.startDate,
                url: event.url,
                isPinned: false,
                iconName: event.isAllDay ? "calendar" : "calendar.badge.clock",
                priority: priorityForEvent(event, now: now)
            )
        }
    }

    private func formatTimeRange(start: Date, end: Date, isAllDay: Bool) -> String {
        if isAllDay { return "All Day" }

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func extractMeetingInfo(from event: EKEvent) -> String {
        if let location = event.location, !location.isEmpty {
            return location
        }
        if let notes = event.notes {
            // Look for meeting links in notes
            let patterns = ["zoom.us", "meet.google.com", "teams.microsoft.com"]
            for pattern in patterns {
                if notes.contains(pattern) {
                    return "Online Meeting"
                }
            }
        }
        return ""
    }

    private func priorityForEvent(_ event: EKEvent, now: Date) -> NotificationPriority {
        let minutesUntilStart = event.startDate.timeIntervalSince(now) / 60

        if minutesUntilStart <= 15 { return .high }
        if minutesUntilStart <= 60 { return .normal }
        return .low
    }
}
