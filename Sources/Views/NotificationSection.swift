import SwiftUI

struct NotificationSection: View {
    let icon: String
    let title: String
    let emptyMessage: String
    let notifications: [WorkNotification]
    let showTopDivider: Bool
    let scrollable: Bool
    let onPin: (WorkNotification) -> Void
    let onTap: (WorkNotification) -> Void

    init(
        icon: String,
        title: String,
        emptyMessage: String,
        notifications: [WorkNotification],
        showTopDivider: Bool = false,
        scrollable: Bool = false,
        onPin: @escaping (WorkNotification) -> Void,
        onTap: @escaping (WorkNotification) -> Void
    ) {
        self.icon = icon
        self.title = title
        self.emptyMessage = emptyMessage
        self.notifications = notifications
        self.showTopDivider = showTopDivider
        self.scrollable = scrollable
        self.onPin = onPin
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showTopDivider {
                Divider()
                    .padding(.horizontal, 12)
            }

            // Section header
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if notifications.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            } else if scrollable {
                ScrollView {
                    notificationList
                        .padding(.vertical, 4)
                }
            } else {
                notificationList
                    .padding(.top, 4)
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: notifications.map(\.id))
    }

    private var notificationList: some View {
        LazyVStack(spacing: 0) {
            ForEach(notifications) { notification in
                NotificationRow(
                    notification: notification,
                    onPin: { onPin(notification) },
                    onTap: { onTap(notification) }
                )
                .transition(.opacity)

                if notification.id != notifications.last?.id {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
    }
}
