import Foundation

// MARK: - Google Calendar Events API

struct GoogleCalendarEventList: Decodable, Sendable {
    let items: [GoogleCalendarEvent]?
    let summary: String? // Calendar name
    let nextPageToken: String?
}

struct GoogleCalendarEvent: Decodable, Sendable {
    let id: String
    let summary: String? // Event title
    let description: String?
    let status: String? // "confirmed", "tentative", "cancelled"
    let start: GoogleDateTime?
    let end: GoogleDateTime?
    let htmlLink: String?
    let hangoutLink: String?
    let conferenceData: ConferenceData?
    let organizer: EventPerson?
    let attendees: [EventAttendee]?

    struct GoogleDateTime: Decodable, Sendable {
        let dateTime: String? // ISO 8601 for timed events
        let date: String? // "2024-01-15" for all-day events
        let timeZone: String?

        var parsed: Date? {
            if let dateTime {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = formatter.date(from: dateTime) { return d }
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: dateTime)
            }
            if let date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: date)
            }
            return nil
        }
    }

    struct ConferenceData: Decodable, Sendable {
        let entryPoints: [EntryPoint]?

        struct EntryPoint: Decodable, Sendable {
            let entryPointType: String? // "video", "phone"
            let uri: String?
        }
    }

    struct EventPerson: Decodable, Sendable {
        let displayName: String?
        let email: String?
    }

    struct EventAttendee: Decodable, Sendable {
        let displayName: String?
        let email: String?
        let responseStatus: String? // "accepted", "declined", "tentative", "needsAction"
        let `self`: Bool?
    }

    var eventTitle: String {
        summary ?? "No Title"
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let startDate = start?.parsed else { return "" }

        if start?.date != nil {
            return "All Day"
        }

        let startStr = formatter.string(from: startDate)
        if let endDate = end?.parsed {
            let endStr = formatter.string(from: endDate)
            return "\(startStr) - \(endStr)"
        }
        return startStr
    }

    var meetingURL: URL? {
        if let link = hangoutLink { return URL(string: link) }
        if let entry = conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" }),
           let uri = entry.uri
        {
            return URL(string: uri)
        }
        return nil
    }

    var browseURL: URL? {
        htmlLink.flatMap { URL(string: $0) }
    }

    var startDate: Date {
        start?.parsed ?? Date.distantFuture
    }
}
