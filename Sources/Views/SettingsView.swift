import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    let settingsStore: SettingsStore
    let oauthManager: OAuthManager
    var notificationStore: NotificationStore?
    @Environment(\.dismiss) private var dismiss
    @State private var authError: String?
    @State private var authenticatingService: ServiceType?
    @State private var githubRepos: [GitHubRepositorySummary] = []
    @State private var githubAccounts: [String] = []
    @State private var githubRepoSearch = ""
    @State private var isLoadingGitHubRepos = false
    @State private var githubRepoError: String?
    @State private var hasLoadedGitHubRepos = false

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
                        let config = settingsStore.serviceConfigs[service]
                            ?? ServiceConfig(isEnabled: false, isAuthenticated: false)

                        VStack(alignment: .leading, spacing: 8) {
                            ServiceSettingsRow(
                                service: service,
                                config: config,
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

                            if service == .github, config.isAuthenticated {
                                githubRepositorySelector
                            }
                        }
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

                Section("GitHub") {
                    Picker("Show notifications from", selection: Binding(
                        get: { settingsStore.githubNotificationDays },
                        set: {
                            settingsStore.setGitHubNotificationDays($0)
                            notificationStore?.updateSections()
                        }
                    )) {
                        Text("Last 1 day").tag(1)
                        Text("Last 3 days").tag(3)
                        Text("Last 1 week").tag(7)
                        Text("Last 2 weeks").tag(14)
                        Text("Last 1 month").tag(30)
                    }
                }

                Section("Calendar") {
                    Picker("Show events for next", selection: Binding(
                        get: { settingsStore.calendarLookaheadHours },
                        set: { settingsStore.setCalendarLookahead($0) }
                    )) {
                        Text("6 hours").tag(6)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                        Text("48 hours").tag(48)
                        Text("72 hours").tag(72)
                    }
                }

                Section("Appearance") {
                    HStack {
                        Text("Background Opacity")
                        Spacer()
                        Text("\(Int(settingsStore.backgroundOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { settingsStore.backgroundOpacity },
                            set: { settingsStore.setBackgroundOpacity($0) }
                        ),
                        in: 0.1...1.0,
                        step: 0.05
                    )
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
        .frame(width: 360, height: 540)
        .onAppear {
            syncAuthState()
            loadGitHubAccounts()
            Task { await loadGitHubRepositoriesIfNeeded() }
        }
        .onChange(of: settingsStore.isAuthenticated(.github)) { _, isAuthenticated in
            if isAuthenticated {
                loadGitHubAccounts()
                Task { await loadGitHubRepositoriesIfNeeded(force: true) }
            } else {
                githubAccounts = []
                githubRepos = []
                githubRepoSearch = ""
                githubRepoError = nil
                hasLoadedGitHubRepos = false
            }
        }
    }

    private func authenticate(_ service: ServiceType) async {
        if service == .github {
            await addGitHubAccount()
            return
        }

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
            if service == .github {
                await loadGitHubRepositoriesIfNeeded(force: true)
            }
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

    private func addGitHubAccount() async {
        authError = nil
        authenticatingService = .github
        let config = oauthConfig(for: .github)

        do {
            let account = try await oauthManager.authenticateGitHubAccount(config: config)
            settingsStore.markAuthenticated(.github, true)
            loadGitHubAccounts()
            settingsStore.setGitHubActiveAccount(login: account.login)
            await loadGitHubRepositoriesIfNeeded(force: true)
            refreshAfterChange()
        } catch {
            if (error as NSError).domain == ASWebAuthenticationSessionError.errorDomain,
               (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                // User cancelled - not an error
            } else {
                authError = "GitHub: \(error.localizedDescription)"
            }
        }

        authenticatingService = nil
    }

    private func signOut(_ service: ServiceType) {
        if service == .github {
            try? oauthManager.disconnectAllGitHubAccounts()
            settingsStore.setGitHubActiveAccount(login: nil)
            settingsStore.clearGitHubRepositorySelection()
            githubAccounts = []
            githubRepos = []
            githubRepoSearch = ""
            githubRepoError = nil
            hasLoadedGitHubRepos = false
        } else {
            try? oauthManager.disconnect(service: service)
        }

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
            let hasTokens: Bool
            if service == .github {
                hasTokens = !keychain.listGitHubAccountLogins().isEmpty || keychain.hasTokens(for: .github)
            } else {
                hasTokens = keychain.hasTokens(for: service)
            }
            if hasTokens != settingsStore.isAuthenticated(service) {
                settingsStore.markAuthenticated(service, hasTokens)
            }
        }
    }

    private func loadGitHubAccounts() {
        githubAccounts = KeychainManager.shared.listGitHubAccountLogins().sorted()

        if let active = settingsStore.githubActiveAccountLogin,
           githubAccounts.contains(active) {
            return
        }

        settingsStore.setGitHubActiveAccount(login: githubAccounts.first)
    }

    private func removeGitHubAccount(_ login: String) {
        try? oauthManager.disconnectGitHubAccount(login: login)
        loadGitHubAccounts()

        if githubAccounts.isEmpty {
            settingsStore.markAuthenticated(.github, false)
            settingsStore.clearGitHubRepositorySelection()
            githubRepos = []
            hasLoadedGitHubRepos = false
        }

        Task {
            await loadGitHubRepositoriesIfNeeded(force: true)
            refreshAfterChange()
        }
    }

    private var filteredGitHubRepos: [GitHubRepositorySummary] {
        if githubRepoSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return githubRepos
        }
        let query = githubRepoSearch.lowercased()
        return githubRepos.filter { $0.full_name.lowercased().contains(query) }
    }

    @ViewBuilder
    private var githubRepositorySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Accounts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if authenticatingService == .github {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Add Account") {
                        Task { await addGitHubAccount() }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                }
            }

            if githubAccounts.isEmpty {
                Text("No linked GitHub accounts")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(githubAccounts, id: \.self) { login in
                    let isActive = settingsStore.githubActiveAccountLogin == login
                    HStack(spacing: 8) {
                        Button {
                            settingsStore.setGitHubActiveAccount(login: login)
                            Task {
                                await loadGitHubRepositoriesIfNeeded(force: true)
                                refreshAfterChange()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                                Text(login)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if githubAccounts.count > 1 {
                            Button(role: .destructive) {
                                removeGitHubAccount(login)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("Repositories")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !settingsStore.githubSelectedRepoNames.isEmpty {
                    Button("Use all") {
                        settingsStore.clearGitHubRepositorySelection()
                        refreshAfterChange()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                }
                Button("Reload") {
                    Task { await loadGitHubRepositoriesIfNeeded(force: true) }
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
            }

            TextField("Search repositories", text: $githubRepoSearch)
                .textFieldStyle(.roundedBorder)

            if isLoadingGitHubRepos {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading repositories...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if let githubRepoError {
                Text(githubRepoError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            } else {
                Text(
                    settingsStore.githubSelectedRepoNames.isEmpty
                        ? "All repositories selected"
                        : "\(settingsStore.githubSelectedRepoNames.count) repositories selected"
                )
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if filteredGitHubRepos.isEmpty {
                            Text("No repositories found")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(filteredGitHubRepos, id: \.full_name) { repo in
                                let selected = settingsStore.githubSelectedRepoNames.contains(repo.full_name)
                                Button {
                                    settingsStore.setGitHubRepositorySelected(
                                        repo.full_name,
                                        selected: !selected
                                    )
                                    refreshAfterChange()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selected ? Color.accentColor : .secondary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(repo.full_name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            HStack(spacing: 6) {
                                                if repo.fork {
                                                    Text("fork")
                                                        .font(.system(size: 9, weight: .semibold))
                                                        .foregroundStyle(.secondary)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1)
                                                        .background(.quaternary)
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                }
                                                if repo.parsedPushedDate != .distantPast {
                                                    Text(repo.parsedPushedDate, style: .relative)
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(.leading, 32)
    }

    private func loadGitHubRepositoriesIfNeeded(force: Bool = false) async {
        guard settingsStore.isAuthenticated(.github) else { return }
        if hasLoadedGitHubRepos, !force { return }
        if isLoadingGitHubRepos { return }

        isLoadingGitHubRepos = true
        githubRepoError = nil
        defer { isLoadingGitHubRepos = false }

        do {
            let token = try activeGitHubAccessToken()
            githubRepos = try await fetchGitHubRepositories(token: token)
            hasLoadedGitHubRepos = true
        } catch {
            githubRepoError = "Failed to load repositories: \(error.localizedDescription)"
        }
    }

    private func activeGitHubAccessToken() throws -> String {
        let keychain = KeychainManager.shared

        if let active = settingsStore.githubActiveAccountLogin,
           let tokens = try keychain.getGitHubTokens(for: active) {
            return tokens.accessToken
        }

        if let tokens = try keychain.getTokens(for: .github) {
            return tokens.accessToken
        }

        throw ServiceError.notAuthenticated
    }

    private func fetchGitHubRepositories(token: String) async throws -> [GitHubRepositorySummary] {
        var page = 1
        var repositories: [GitHubRepositorySummary] = []

        while page <= 5 {
            var components = URLComponents(string: "https://api.github.com/user/repos")!
            components.queryItems = [
                URLQueryItem(name: "type", value: "all"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
            ]
            guard let url = components.url else { break }

            let chunk: [GitHubRepositorySummary] = try await HTTPClient.shared.get(
                url: url,
                bearerToken: token,
                additionalHeaders: ["Accept": "application/vnd.github+json"]
            )
            repositories.append(contentsOf: chunk)

            if chunk.count < 100 { break }
            page += 1
        }

        return repositories
    }

    private func oauthConfig(for service: ServiceType) -> OAuthConfig {
        // Read from environment variables or use placeholders
        switch service {
        case .github:
            return .github(
                clientID: DotEnv.get("GITHUB_CLIENT_ID", default: "YOUR_GITHUB_CLIENT_ID"),
                clientSecret: DotEnv.get("GITHUB_CLIENT_SECRET", default: "YOUR_GITHUB_CLIENT_SECRET")
            )
        case .teams:
            return .microsoft(
                clientID: DotEnv.get("MICROSOFT_CLIENT_ID", default: "YOUR_TEAMS_CLIENT_ID")
            )
        case .notion:
            return .notion(
                clientID: DotEnv.get("NOTION_CLIENT_ID", default: "YOUR_NOTION_CLIENT_ID"),
                clientSecret: DotEnv.get("NOTION_CLIENT_SECRET", default: "YOUR_NOTION_CLIENT_SECRET")
            )
        case .googleCalendar:
            return .google(
                clientID: DotEnv.get("GOOGLE_CLIENT_ID", default: "YOUR_GOOGLE_CLIENT_ID")
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
