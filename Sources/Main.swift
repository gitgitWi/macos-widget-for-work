import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private let notificationStore = NotificationStore()
    private let settingsStore = SettingsStore()
    private var oauthManager: OAuthManager!

    nonisolated static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        oauthManager = OAuthManager()

        // Create real service instances
        let services: [any NotificationService] = [
            GitHubService(oauthManager: oauthManager),
            TeamsService(oauthManager: oauthManager),
            NotionService(oauthManager: oauthManager),
            EventKitCalendarService(),
            GoogleCalendarService(oauthManager: oauthManager),
        ]
        notificationStore.configure(services: services, settingsStore: settingsStore)

        setupStatusItem()

        panelController = PanelController(
            notificationStore: notificationStore,
            settingsStore: settingsStore,
            oauthManager: oauthManager
        )
        panelController.showPanel()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "bell.badge",
                accessibilityDescription: "Work Widget"
            )
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    @objc private func togglePanel() {
        panelController.togglePanel()
    }
}
