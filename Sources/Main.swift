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
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            panelController.togglePanel()
            return
        }

        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            panelController.togglePanel()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show/Hide Panel", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit WorkWidget", action: #selector(quitApp), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Remove menu after showing so left-click still toggles panel
        statusItem.menu = nil
    }

    @objc private func togglePanel() {
        panelController.togglePanel()
    }

    @objc private func quitApp() {
        notificationStore.stopPolling()
        NSApp.terminate(nil)
    }
}
