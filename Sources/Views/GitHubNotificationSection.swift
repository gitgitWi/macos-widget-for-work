import SwiftUI

struct GitHubNotificationSection: View {
    let notifications: [WorkNotification]
    let onPin: (WorkNotification) -> Void
    let onTap: (WorkNotification) -> Void

    private var repoGroups: [(repoName: String, notifications: [WorkNotification])] {
        let grouped = Dictionary(grouping: notifications) { $0.subtitle }
        return grouped
            .map { (repoName: $0.key, notifications: Array($0.value.prefix(3))) }
            .sorted { group1, group2 in
                let latest1 = group1.notifications.first?.timestamp ?? .distantPast
                let latest2 = group2.notifications.first?.timestamp ?? .distantPast
                return latest1 > latest2
            }
    }

    private var displayedNotificationCount: Int {
        repoGroups.reduce(0) { $0 + $1.notifications.count }
    }

    private var scrollContentHeight: CGFloat {
        let estimatedRowHeight: CGFloat = 54
        let estimatedGroupHeaderHeight: CGFloat = 22
        let estimatedVerticalPadding: CGFloat = 8
        let estimatedDividersHeight: CGFloat = CGFloat(max(displayedNotificationCount - repoGroups.count, 0))

        let estimated = (CGFloat(displayedNotificationCount) * estimatedRowHeight)
            + (CGFloat(repoGroups.count) * estimatedGroupHeaderHeight)
            + estimatedVerticalPadding
            + estimatedDividersHeight

        return min(max(estimated, 88), 250)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, 12)

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                Text("GitHub")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if notifications.isEmpty {
                Text("No GitHub notifications")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(repoGroups, id: \.repoName) { group in
                            repoGroupView(group)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: scrollContentHeight, alignment: .top)
                .clipped()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: notifications.map(\.id))
    }

    @ViewBuilder
    private func repoGroupView(_ group: (repoName: String, notifications: [WorkNotification])) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .font(.system(size: 9))
            Text(group.repoName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)

        ForEach(group.notifications) { notification in
            NotificationRow(
                notification: notification,
                onPin: { onPin(notification) },
                onTap: { onTap(notification) }
            )
            .transition(.opacity)

            if notification.id != group.notifications.last?.id {
                Divider()
                    .padding(.leading, 46)
            }
        }
    }
}
