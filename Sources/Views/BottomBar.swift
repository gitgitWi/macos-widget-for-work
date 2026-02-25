import SwiftUI

struct BottomBar: View {
    let isRefreshing: Bool
    let lastRefresh: Date?
    var backgroundOpacity: Double = 1.0
    let onRefresh: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)

            if let lastRefresh {
                Text(lastRefresh, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial.opacity(backgroundOpacity))
        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
    }
}
