import SwiftUI

struct NotificationRow: View {
    let notification: WorkNotification
    let onPin: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: notification.iconName)
                .font(.system(size: 16))
                .foregroundStyle(colorForService(notification.service))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                if !notification.subtitle.isEmpty {
                    Text(notification.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(notification.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Button(action: onPin) {
                Image(systemName: notification.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10))
                    .foregroundStyle(notification.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .background {
            if notification.priority >= .high {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.orange.opacity(0.08))
            }
        }
    }

    private func colorForService(_ service: ServiceType) -> Color {
        switch service {
        case .teams: .purple
        case .github: .primary
        case .notion: .primary
        case .eventKit: .red
        case .googleCalendar: .blue
        }
    }
}
