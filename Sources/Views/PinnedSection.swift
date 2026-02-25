import SwiftUI

struct PinnedSection: View {
    let notifications: [WorkNotification]
    let onUnpin: (WorkNotification) -> Void
    let onTap: (WorkNotification) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                Text("Pinned")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if notifications.isEmpty {
                Text("No pinned notifications")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(notifications) { notification in
                    NotificationRow(
                        notification: notification,
                        onPin: { onUnpin(notification) },
                        onTap: { onTap(notification) }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: notifications.map(\.id))
    }
}
