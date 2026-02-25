import SwiftUI

struct RecentSection: View {
    let notifications: [WorkNotification]
    let onPin: (WorkNotification) -> Void
    let onTap: (WorkNotification) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("Recent")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if notifications.isEmpty {
                Text("No recent notifications")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            NotificationRow(
                                notification: notification,
                                onPin: { onPin(notification) },
                                onTap: { onTap(notification) }
                            )

                            if notification.id != notifications.last?.id {
                                Divider()
                                    .padding(.leading, 46)
                            }
                        }
                    }
                }
            }
        }
    }
}
