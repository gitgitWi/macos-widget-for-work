import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    let settingsStore: SettingsStore
    let oauthManager: OAuthManager
    var notificationStore: NotificationStore?
    @Environment(\.dismiss) private var dismiss
    @State private var authError: String?
    @State private var authenticatingService: ServiceType?

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
                            isAuthenticating: authenticatingService == service,
                            onToggleVisibility: {
                                settingsStore.toggleVisibility(for: service)
                                refreshAfterChange()
                            },
                            onAuthenticate: {
                                Task { await authenticate(service) }
                            },
                            onSignOut: {
                                signOut(service)
                            }
                        )
                    }
                }

                Section("Refresh Interval") {
                    Picker("Poll every", selection: Binding(
                        get: { settingsStore.pollIntervalSeconds },
                        set: { settingsStore.setPollInterval($0) }
                    )) {
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                    }
                }

                if let authError {
                    Section {
                        Text(authError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 360, height: 420)
        .onAppear {
            syncAuthState()
        }
    }

    private func authenticate(_ service: ServiceType) async {
        authError = nil
        authenticatingService = service

        if service == .eventKit {
            // EventKit uses system permission dialog, not OAuth
            settingsStore.markAuthenticated(service, true)
            authenticatingService = nil
            return
        }

        // Load config - for now use placeholder client IDs
        // Users should set their own via environment or config file
        let config = oauthConfig(for: service)

        do {
            try await oauthManager.authenticate(service: service, config: config)
            settingsStore.markAuthenticated(service, true)
            refreshAfterChange()
        } catch {
            if (error as NSError).domain == ASWebAuthenticationSessionError.errorDomain,
               (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                // User cancelled - not an error
            } else {
                authError = "\(service.displayName): \(error.localizedDescription)"
            }
        }

        authenticatingService = nil
    }

    private func signOut(_ service: ServiceType) {
        try? oauthManager.disconnect(service: service)
        settingsStore.markAuthenticated(service, false)
        notificationStore?.clearError(for: service)
        refreshAfterChange()
    }

    private func refreshAfterChange() {
        guard let store = notificationStore else { return }
        Task { await store.refreshAll() }
    }

    /// Sync Keychain state with SettingsStore on appear
    private func syncAuthState() {
        let keychain = KeychainManager.shared
        for service in ServiceType.allCases where service != .eventKit {
            let hasTokens = keychain.hasTokens(for: service)
            if hasTokens != settingsStore.isAuthenticated(service) {
                settingsStore.markAuthenticated(service, hasTokens)
            }
        }
    }

    private func oauthConfig(for service: ServiceType) -> OAuthConfig {
        // Read from environment variables or use placeholders
        switch service {
        case .github:
            return .github(
                clientID: ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] ?? "YOUR_GITHUB_CLIENT_ID",
                clientSecret: ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] ?? "YOUR_GITHUB_CLIENT_SECRET"
            )
        case .teams:
            return .microsoft(
                clientID: ProcessInfo.processInfo.environment["TEAMS_CLIENT_ID"] ?? "YOUR_TEAMS_CLIENT_ID"
            )
        case .notion:
            return .notion(
                clientID: ProcessInfo.processInfo.environment["NOTION_CLIENT_ID"] ?? "YOUR_NOTION_CLIENT_ID",
                clientSecret: ProcessInfo.processInfo.environment["NOTION_CLIENT_SECRET"] ?? "YOUR_NOTION_CLIENT_SECRET"
            )
        case .googleCalendar:
            return .google(
                clientID: ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? "YOUR_GOOGLE_CLIENT_ID"
            )
        case .eventKit:
            fatalError("EventKit does not use OAuth")
        }
    }
}

struct ServiceSettingsRow: View {
    let service: ServiceType
    let config: ServiceConfig
    var isAuthenticating: Bool = false
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

            if isAuthenticating {
                ProgressView()
                    .controlSize(.small)
            } else if config.isAuthenticated {
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
