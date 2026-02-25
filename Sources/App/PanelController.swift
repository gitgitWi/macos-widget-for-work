import AppKit
import SwiftUI

/// An NSHostingView subclass that automatically resizes its window
/// to match the SwiftUI content's intrinsic size.
/// Uses debounce to avoid resizing during hover animations.
private final class AutoSizingHostingView<Content: View>: NSHostingView<Content> {
    private var resizeWorkItem: DispatchWorkItem?
    private let maxPanelHeight: CGFloat = 700

    @MainActor
    override func layout() {
        super.layout()
        guard let window else { return }
        let targetHeight = min(fittingSize.height, maxPanelHeight)
        guard abs(window.frame.height - targetHeight) > 2 else { return }

        // Cancel any pending resize — debounce so hover animations don't trigger resizing
        resizeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak window] in
            guard let self, let window else { return }
            let finalHeight = min(self.fittingSize.height, self.maxPanelHeight)
            guard abs(window.frame.height - finalHeight) > 2 else { return }
            let newOrigin = NSPoint(
                x: window.frame.origin.x,
                y: window.frame.maxY - finalHeight
            )
            let newFrame = NSRect(
                origin: newOrigin,
                size: NSSize(width: window.frame.width, height: finalHeight)
            )
            window.setFrame(newFrame, display: true, animate: false)
        }
        resizeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
}

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

    func showPanel(anchorFrame: NSRect? = nil) {
        if panel == nil {
            createPanel(anchorFrame: anchorFrame)
        } else if let anchorFrame {
            repositionPanel(relativeTo: anchorFrame)
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

    func togglePanel(anchorFrame: NSRect? = nil) {
        if isVisible {
            hidePanel()
        } else {
            showPanel(anchorFrame: anchorFrame)
        }
    }

    private func createPanel(anchorFrame: NSRect? = nil) {
        let panelWidth: CGFloat = 320

        let rootView = PanelContentView(
            notificationStore: notificationStore,
            settingsStore: settingsStore,
            oauthManager: oauthManager
        )

        let hostingView = AutoSizingHostingView(rootView: rootView)
        let fittingHeight = min(hostingView.fittingSize.height, 700)

        let contentRect: NSRect

        if let anchorFrame {
            let screen = NSScreen.screens.first { $0.frame.contains(anchorFrame.origin) } ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? .zero

            let originX = anchorFrame.midX - (panelWidth / 2)
            let originY = anchorFrame.minY - fittingHeight

            let clampedX = max(screenFrame.minX, min(originX, screenFrame.maxX - panelWidth))
            let clampedY = max(screenFrame.minY, originY)

            contentRect = NSRect(x: clampedX, y: clampedY, width: panelWidth, height: fittingHeight)
        } else {
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            let originX = screenFrame.maxX - panelWidth - 12
            let originY = screenFrame.maxY - fittingHeight
            contentRect = NSRect(x: originX, y: originY, width: panelWidth, height: fittingHeight)
        }

        let panel = SidebarPanel(contentRect: contentRect)
        panel.contentView = hostingView

        self.panel = panel
    }

    private func repositionPanel(relativeTo anchorFrame: NSRect) {
        guard let panel else { return }

        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        let screen = NSScreen.screens.first { $0.frame.contains(anchorFrame.origin) } ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? .zero

        let originX = anchorFrame.midX - (panelWidth / 2)
        let originY = anchorFrame.minY - panelHeight

        let clampedX = max(screenFrame.minX, min(originX, screenFrame.maxX - panelWidth))
        let clampedY = max(screenFrame.minY, originY)

        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}
