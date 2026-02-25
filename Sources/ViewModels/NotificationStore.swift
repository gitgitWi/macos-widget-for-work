import Foundation

@Observable
final class NotificationStore: @unchecked Sendable {
    var pinnedNotifications: [WorkNotification] = []
    var recentNotifications: [WorkNotification] = []
    var calendarNotifications: [WorkNotification] = []
    var isRefreshing: Bool = false
    var lastRefreshDate: Date?
    var errors: [ServiceType: String] = [:]
    var isShowingMockData: Bool = false

    private var allNotifications: [WorkNotification] = []
    private var pinnedIDs: Set<String> = []
    private let maxPinned = 3
    private let maxRecent = 7

    private let defaults = UserDefaults.standard
    private let pinnedKey = "pinnedNotificationIDs"

    private var services: [any NotificationService] = []
    private weak var settingsStore: SettingsStore?
    private var pollingTask: Task<Void, Never>?

    init() {
        loadPinnedIDs()
    }

    /// Configure with real services and settings. Called after dependency injection.
    func configure(services: [any NotificationService], settingsStore: SettingsStore) {
        self.services = services
        self.settingsStore = settingsStore
    }

    // MARK: - Polling

    @MainActor
    func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.settingsStore?.pollIntervalSeconds ?? 60
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refreshAll()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    func refreshAll() async {
        isRefreshing = true
        errors = [:]

        let enabledServices = services.filter { service in
            settingsStore?.isServiceEnabled(service.serviceType) ?? false
        }

        if enabledServices.isEmpty {
            // No services connected - show mock data
            allNotifications = Self.generateMockNotifications()
            isShowingMockData = true
        } else {
            // Fetch from all enabled services concurrently
            var fetched: [WorkNotification] = []

            await withTaskGroup(of: (ServiceType, Result<[WorkNotification], Error>).self) { group in
                for service in enabledServices {
                    group.addTask {
                        do {
                            let notifications = try await service.fetchNotifications()
                            return (service.serviceType, .success(notifications))
                        } catch {
                            return (service.serviceType, .failure(error))
                        }
                    }
                }

                for await (serviceType, result) in group {
                    switch result {
                    case .success(let notifications):
                        fetched.append(contentsOf: notifications)
                    case .failure(let error):
                        errors[serviceType] = error.localizedDescription
                    }
                }
            }

            allNotifications = fetched
            isShowingMockData = false
        }

        updateSections()
        isRefreshing = false
        lastRefreshDate = Date()
    }

    func clearError(for service: ServiceType) {
        errors.removeValue(forKey: service)
    }

    func togglePin(_ notification: WorkNotification) {
        if pinnedIDs.contains(notification.id) {
            pinnedIDs.remove(notification.id)
        } else {
            guard pinnedIDs.count < maxPinned else { return }
            pinnedIDs.insert(notification.id)
        }
        savePinnedIDs()
        updateSections()
    }

    private func updateSections() {
        let now = Date()

        let pinned = allNotifications
            .filter { pinnedIDs.contains($0.id) }
            .map { var n = $0; n.isPinned = true; return n }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(maxPinned)

        // Non-calendar, non-pinned → Recent
        let recent = allNotifications
            .filter { !pinnedIDs.contains($0.id) && !$0.service.isCalendar }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(maxRecent)

        // Calendar, non-pinned, future only → Calendar section (ascending)
        let calendar = allNotifications
            .filter { !pinnedIDs.contains($0.id) && $0.service.isCalendar && $0.timestamp >= now }
            .sorted { $0.timestamp < $1.timestamp }

        pinnedNotifications = Array(pinned)
        recentNotifications = Array(recent)
        calendarNotifications = Array(calendar)
    }

    private func loadPinnedIDs() {
        if let array = defaults.stringArray(forKey: pinnedKey) {
            pinnedIDs = Set(array)
        }
    }

    private func savePinnedIDs() {
        defaults.set(Array(pinnedIDs), forKey: pinnedKey)
    }

    // MARK: - Mock Data (shown when no services are connected)

    static func generateMockNotifications() -> [WorkNotification] {
        let now = Date()
        return [
            WorkNotification(
                id: "gh-1001",
                service: .github,
                title: "PR #42: Add dark mode support",
                subtitle: "octocat/my-project",
                body: "Review requested",
                timestamp: now.addingTimeInterval(-300),
                url: nil,
                isPinned: false,
                iconName: "arrow.triangle.branch",
                priority: .high
            ),
            WorkNotification(
                id: "teams-2001",
                service: .teams,
                title: "Sprint Planning Meeting",
                subtitle: "John Doe",
                body: "Let's discuss the Q1 roadmap",
                timestamp: now.addingTimeInterval(-600),
                url: nil,
                isPinned: false,
                iconName: "bubble.left.and.bubble.right",
                priority: .normal
            ),
            WorkNotification(
                id: "notion-3001",
                service: .notion,
                title: "Project Roadmap updated",
                subtitle: "Updated 10 minutes ago",
                body: "",
                timestamp: now.addingTimeInterval(-900),
                url: nil,
                isPinned: false,
                iconName: "doc.text",
                priority: .normal
            ),
            WorkNotification(
                id: "cal-4001",
                service: .eventKit,
                title: "1:1 with Manager",
                subtitle: "2:00 PM - 2:30 PM",
                body: "Zoom Meeting",
                timestamp: now.addingTimeInterval(1800),
                url: nil,
                isPinned: false,
                iconName: "calendar",
                priority: .high
            ),
            WorkNotification(
                id: "gh-1002",
                service: .github,
                title: "Issue #87: Fix login timeout",
                subtitle: "octocat/api-server",
                body: "Assigned to you",
                timestamp: now.addingTimeInterval(-1800),
                url: nil,
                isPinned: false,
                iconName: "arrow.triangle.branch",
                priority: .normal
            ),
            WorkNotification(
                id: "teams-2002",
                service: .teams,
                title: "Design Review Feedback",
                subtitle: "Jane Smith",
                body: "I've left comments on the wireframe",
                timestamp: now.addingTimeInterval(-2400),
                url: nil,
                isPinned: false,
                iconName: "bubble.left.and.bubble.right",
                priority: .normal
            ),
            WorkNotification(
                id: "gcal-5001",
                service: .googleCalendar,
                title: "Team Standup",
                subtitle: "9:00 AM - 9:15 AM",
                body: "Google Meet",
                timestamp: now.addingTimeInterval(3600),
                url: nil,
                isPinned: false,
                iconName: "calendar.badge.clock",
                priority: .normal
            ),
            WorkNotification(
                id: "notion-3002",
                service: .notion,
                title: "API Documentation draft",
                subtitle: "Updated 1 hour ago",
                body: "",
                timestamp: now.addingTimeInterval(-3600),
                url: nil,
                isPinned: false,
                iconName: "doc.text",
                priority: .low
            ),
            WorkNotification(
                id: "gh-1003",
                service: .github,
                title: "Release v2.1.0 published",
                subtitle: "octocat/my-project",
                body: "New release",
                timestamp: now.addingTimeInterval(-5400),
                url: nil,
                isPinned: false,
                iconName: "arrow.triangle.branch",
                priority: .low
            ),
            WorkNotification(
                id: "teams-2003",
                service: .teams,
                title: "Deployment notification",
                subtitle: "DevOps Bot",
                body: "Production deployment completed successfully",
                timestamp: now.addingTimeInterval(-7200),
                url: nil,
                isPinned: false,
                iconName: "bubble.left.and.bubble.right",
                priority: .low
            ),
        ]
    }
}
