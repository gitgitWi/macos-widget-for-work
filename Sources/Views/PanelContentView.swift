import AppKit
import SwiftUI

struct PanelContentView: View {
    let notificationStore: NotificationStore
    let settingsStore: SettingsStore
    let oauthManager: OAuthManager
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

            if notificationStore.isShowingMockData {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                    Text("Sample data — connect services in Settings")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.quaternary.opacity(0.5))
            }

            // Error banner for failed services
            if !notificationStore.errors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(notificationStore.errors), id: \.key) { service, message in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("\(service.displayName): \(message)")
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Spacer()
                            if service == .eventKit {
                                Button("Open Settings") {
                                    openPrivacySettings()
                                }
                                .font(.system(size: 9, weight: .medium))
                                .buttonStyle(.plain)
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            NotificationSection(
                icon: "pin.fill",
                title: "Pinned",
                emptyMessage: "No pinned notifications",
                notifications: notificationStore.pinnedNotifications,
                onPin: { notificationStore.togglePin($0) },
                onTap: { openURL($0.url) }
            )

            if !notificationStore.githubNotifications.isEmpty || settingsStore.isServiceEnabled(.github) {
                GitHubNotificationSection(
                    notifications: notificationStore.githubNotifications,
                    onPin: { notificationStore.togglePin($0) },
                    onTap: { openURL($0.url) }
                )
            }

            NotificationSection(
                icon: "clock",
                title: "Recent",
                emptyMessage: "No recent notifications",
                notifications: notificationStore.recentNotifications,
                showTopDivider: true,
                scrollable: true,
                onPin: { notificationStore.togglePin($0) },
                onTap: { openURL($0.url) }
            )
            .frame(maxHeight: notificationStore.recentNotifications.isEmpty ? 50 : 280)

            NotificationSection(
                icon: "calendar",
                title: "Upcoming",
                emptyMessage: "No upcoming events",
                notifications: notificationStore.calendarNotifications,
                showTopDivider: true,
                scrollable: true,
                onPin: { notificationStore.togglePin($0) },
                onTap: { openURL($0.url) }
            )
            .frame(maxHeight: 200)

            BottomBar(
                isRefreshing: notificationStore.isRefreshing,
                lastRefresh: notificationStore.lastRefreshDate,
                backgroundOpacity: settingsStore.backgroundOpacity,
                onRefresh: {
                    Task { await notificationStore.refreshAll() }
                },
                onSettings: { showSettings = true }
            )
        }
        .frame(width: 308)
        .background(.ultraThinMaterial.opacity(settingsStore.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: notificationStore.errors.count)
        .animation(.easeInOut(duration: 0.2), value: notificationStore.isShowingMockData)
        .sheet(isPresented: $showSettings) {
            SettingsView(settingsStore: settingsStore, oauthManager: oauthManager, notificationStore: notificationStore)
        }
        .task {
            await notificationStore.refreshAll()
            notificationStore.startPolling()
        }
    }

    private func openURL(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
