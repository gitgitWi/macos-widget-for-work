import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private var panel: SidebarPanel?
    private let notificationStore: NotificationStore
    private let settingsStore: SettingsStore
    private let oauthManager: OAuthManager

    init(notificationStore: NotificationStore, settingsStore: SettingsStore, oauthManager: OAuthManager) {
        self.notificationStore = notificationStore
        self.settingsStore = settingsStore
        self.oauthManager = oauthManager
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func showPanel() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFrontRegardless()

        // Set the panel as the OAuth presentation anchor
        if let panel {
            oauthManager.setPresentationAnchor(panel)
        }
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func createPanel() {
        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 600
        let screenFrame = screen.visibleFrame
        let originX = screenFrame.maxX - panelWidth - 12
        let originY = screenFrame.midY - (panelHeight / 2)

        let contentRect = NSRect(
            x: originX, y: originY,
            width: panelWidth, height: panelHeight
        )

        let panel = SidebarPanel(contentRect: contentRect)

        let rootView = PanelContentView(
            notificationStore: notificationStore,
            settingsStore: settingsStore,
            oauthManager: oauthManager
        )

        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView

        self.panel = panel
    }
}
