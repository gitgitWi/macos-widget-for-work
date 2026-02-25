import AppKit
import SwiftUI

struct PanelContentView: View {
    let notificationStore: NotificationStore
    let settingsStore: SettingsStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area
            HStack {
                Text("Work Widget")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            PinnedSection(
                notifications: notificationStore.pinnedNotifications,
                onUnpin: { notificationStore.togglePin($0) },
                onTap: { openURL($0.url) }
            )

            Divider()
                .padding(.horizontal, 12)

            RecentSection(
                notifications: notificationStore.recentNotifications,
                onPin: { notificationStore.togglePin($0) },
                onTap: { openURL($0.url) }
            )

            Spacer(minLength: 0)

            BottomBar(
                isRefreshing: notificationStore.isRefreshing,
                lastRefresh: notificationStore.lastRefreshDate,
                onRefresh: {
                    Task { await notificationStore.refreshAll() }
                },
                onSettings: { showSettings = true }
            )
        }
        .frame(width: 308, height: 580)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showSettings) {
            SettingsView(settingsStore: settingsStore)
        }
        .task {
            await notificationStore.refreshAll()
        }
    }

    private func openURL(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
