import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private let notificationStore = NotificationStore()
    private let settingsStore = SettingsStore()
    private var oauthManager: OAuthManager!

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        oauthManager = OAuthManager()

        setupStatusItem()

        panelController = PanelController(
            notificationStore: notificationStore,
            settingsStore: settingsStore,
            oauthManager: oauthManager
        )
        panelController.showPanel()
    }

    @MainActor
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

    @MainActor
    @objc private func togglePanel() {
        panelController.togglePanel()
    }
}
