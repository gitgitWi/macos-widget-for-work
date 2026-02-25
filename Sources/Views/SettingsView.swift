import SwiftUI

struct SettingsView: View {
    let settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
            .padding()

            Form {
                Section("Services") {
                    ForEach(ServiceType.allCases) { service in
                        ServiceSettingsRow(
                            service: service,
                            config: settingsStore.serviceConfigs[service]
                                ?? ServiceConfig(isEnabled: false, isAuthenticated: false),
                            onToggleVisibility: {
                                settingsStore.toggleVisibility(for: service)
                            },
                            onAuthenticate: {
                                // OAuth will be implemented in Phase 2
                                settingsStore.markAuthenticated(service, true)
                            },
                            onSignOut: {
                                settingsStore.markAuthenticated(service, false)
                            }
                        )
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 360, height: 420)
    }
}

struct ServiceSettingsRow: View {
    let service: ServiceType
    let config: ServiceConfig
    let onToggleVisibility: () -> Void
    let onAuthenticate: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        HStack {
            Image(systemName: service.systemImage)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(service.displayName)
                    .font(.system(size: 13, weight: .medium))

                Text(config.isAuthenticated ? "Connected" : "Not connected")
                    .font(.system(size: 11))
                    .foregroundStyle(config.isAuthenticated ? .green : .secondary)
            }

            Spacer()

            if config.isAuthenticated {
                Toggle("", isOn: Binding(
                    get: { config.isEnabled },
                    set: { _ in onToggleVisibility() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)

                Button("Sign Out", action: onSignOut)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
            } else {
                Button("Connect", action: onAuthenticate)
                    .font(.system(size: 11))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}
