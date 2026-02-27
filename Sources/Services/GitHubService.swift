import Foundation

final class GitHubService: NotificationService, Sendable {
    let serviceType: ServiceType = .github

    private let httpClient = HTTPClient.shared
    private let keychain = KeychainManager.shared
    private let baseURL = "https://api.github.com"
    private let commitBaselineKey = AppDefaultsKeys.githubDefaultBranchCommitBaseline

    init(oauthManager: OAuthManager) {
        _ = oauthManager
    }

    func fetchNotifications() async throws -> [WorkNotification] {
        let token = try await getValidToken()
        let selectedRepos = loadSelectedRepositories()

        let threadNotifications = (try? await fetchParticipatingThreadNotifications(
            token: token,
            selectedRepos: selectedRepos
        )) ?? []
        let pullRequests = (try? await fetchParticipatingPullRequests(
            token: token,
            selectedRepos: selectedRepos
        )) ?? []
        let issues = (try? await fetchParticipatingIssues(
            token: token,
            selectedRepos: selectedRepos
        )) ?? []
        let defaultBranchCommits = (try? await fetchDefaultBranchCommitNotifications(
            token: token,
            selectedRepos: selectedRepos
        )) ?? []

        let combined = (threadNotifications + pullRequests + issues + defaultBranchCommits)
            .sorted { $0.timestamp > $1.timestamp }

        return Array(deduplicate(combined).prefix(15))
    }

    private func getValidToken() async throws -> String {
        if let active = UserDefaults.standard.string(forKey: AppDefaultsKeys.githubActiveAccountLogin),
           let tokens = try keychain.getGitHubTokens(for: active) {
            return tokens.accessToken
        }

        if let firstLogin = keychain.listGitHubAccountLogins().first,
           let tokens = try keychain.getGitHubTokens(for: firstLogin) {
            UserDefaults.standard.set(firstLogin, forKey: AppDefaultsKeys.githubActiveAccountLogin)
            return tokens.accessToken
        }

        guard let tokens = try keychain.getTokens(for: .github) else {
            throw ServiceError.notAuthenticated
        }
        // GitHub tokens don't expire (PAT-style from OAuth), return as-is
        return tokens.accessToken
    }

    // MARK: - API Sources

    private func fetchParticipatingThreadNotifications(
        token: String,
        selectedRepos: Set<String>
    ) async throws -> [WorkNotification] {
        let url = URL(string: "\(baseURL)/notifications?participating=true&per_page=20")!
        let notifications: [GitHubNotification] = try await httpClient.get(
            url: url,
            bearerToken: token,
            additionalHeaders: ["Accept": "application/vnd.github+json"]
        )

        return notifications
            .filter { selectedRepos.isEmpty || selectedRepos.contains($0.repository.full_name) }
            .prefix(8)
            .map { notification in
                WorkNotification(
                    id: "gh-thread-\(notification.id)",
                    service: .github,
                    title: notification.subject.title,
                    subtitle: notification.repository.full_name,
                    body: notification.reason.replacingOccurrences(of: "_", with: " ").capitalized,
                    timestamp: notification.parsedDate,
                    url: notification.htmlURL,
                    isPinned: false,
                    iconName: notification.iconName,
                    priority: notification.priority
                )
            }
    }

    private func fetchParticipatingPullRequests(
        token: String,
        selectedRepos: Set<String>
    ) async throws -> [WorkNotification] {
        let items = try await searchIssues(
            token: token,
            query: "is:pr is:open involves:@me",
            perPage: 6
        ).filter { $0.pull_request != nil }
            .filter { selectedRepos.isEmpty || selectedRepos.contains($0.repositoryFullName) }

        return items.map { item in
            WorkNotification(
                id: "gh-pr-\(item.node_id)",
                service: .github,
                title: "PR #\(item.number): \(item.title)",
                subtitle: item.repositoryFullName,
                body: "Open pull request involving you",
                timestamp: item.parsedUpdatedDate,
                url: item.htmlURL,
                isPinned: false,
                iconName: "arrow.triangle.pull",
                priority: .high
            )
        }
    }

    private func fetchParticipatingIssues(
        token: String,
        selectedRepos: Set<String>
    ) async throws -> [WorkNotification] {
        let items = try await searchIssues(
            token: token,
            query: "is:issue is:open involves:@me",
            perPage: 6
        ).filter { $0.pull_request == nil }
            .filter { selectedRepos.isEmpty || selectedRepos.contains($0.repositoryFullName) }

        return items.map { item in
            WorkNotification(
                id: "gh-issue-\(item.node_id)",
                service: .github,
                title: "Issue #\(item.number): \(item.title)",
                subtitle: item.repositoryFullName,
                body: "Open issue involving you",
                timestamp: item.parsedUpdatedDate,
                url: item.htmlURL,
                isPinned: false,
                iconName: "exclamationmark.circle",
                priority: .normal
            )
        }
    }

    private func fetchDefaultBranchCommitNotifications(
        token: String,
        selectedRepos: Set<String>
    ) async throws -> [WorkNotification] {
        var repos = try await fetchParticipatingRepositories(token: token)
        if selectedRepos.isEmpty {
            repos = Array(repos.prefix(8))
        } else {
            repos = repos.filter { selectedRepos.contains($0.full_name) }
        }
        guard !repos.isEmpty else { return [] }

        var baseline = loadCommitBaseline()
        let hasBaseline = !baseline.isEmpty
        var commitNotifications: [WorkNotification] = []

        for repo in repos {
            guard let latestCommit = try? await fetchLatestDefaultBranchCommit(repo: repo, token: token) else {
                continue
            }

            let previousSHA = baseline[repo.full_name]
            baseline[repo.full_name] = latestCommit.sha

            // First run sets baseline only; new repos also establish baseline first.
            guard hasBaseline, let previousSHA, previousSHA != latestCommit.sha else {
                continue
            }

            commitNotifications.append(
                WorkNotification(
                    id: "gh-commit-\(repo.full_name)-\(latestCommit.sha)",
                    service: .github,
                    title: "\(repo.full_name) default branch updated",
                    subtitle: "Latest on \(repo.default_branch)",
                    body: latestCommit.shortMessage,
                    timestamp: latestCommit.parsedAuthorDate,
                    url: latestCommit.htmlURL,
                    isPinned: false,
                    iconName: "arrow.up.circle",
                    priority: .normal
                )
            )
        }

        let activeRepoNames = Set(repos.map(\.full_name))
        baseline = baseline.filter { activeRepoNames.contains($0.key) }
        saveCommitBaseline(baseline)
        return commitNotifications
    }

    private func searchIssues(
        token: String,
        query: String,
        perPage: Int
    ) async throws -> [GitHubSearchItem] {
        var components = URLComponents(string: "\(baseURL)/search/issues")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: String(perPage)),
        ]
        guard let url = components.url else {
            throw ServiceError.apiError("Invalid GitHub search URL")
        }

        let response: GitHubSearchResponse = try await httpClient.get(
            url: url,
            bearerToken: token,
            additionalHeaders: ["Accept": "application/vnd.github+json"]
        )
        return response.items
    }

    private func fetchParticipatingRepositories(token: String) async throws -> [GitHubRepositorySummary] {
        var page = 1
        var repositories: [GitHubRepositorySummary] = []

        while page <= 5 {
            var components = URLComponents(string: "\(baseURL)/user/repos")!
            components.queryItems = [
                URLQueryItem(name: "type", value: "all"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
            ]
            guard let url = components.url else {
                throw ServiceError.apiError("Invalid GitHub repositories URL")
            }

            let chunk: [GitHubRepositorySummary] = try await httpClient.get(
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

    private func fetchLatestDefaultBranchCommit(
        repo: GitHubRepositorySummary,
        token: String
    ) async throws -> GitHubCommit {
        let encodedBranch = repo.default_branch.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        ) ?? repo.default_branch

        let url = URL(string: "\(baseURL)/repos/\(repo.full_name)/commits/\(encodedBranch)")!
        return try await httpClient.get(
            url: url,
            bearerToken: token,
            additionalHeaders: ["Accept": "application/vnd.github+json"]
        )
    }

    // MARK: - Local State

    private func loadCommitBaseline() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: commitBaselineKey) as? [String: String] ?? [:]
    }

    private func saveCommitBaseline(_ baseline: [String: String]) {
        UserDefaults.standard.set(baseline, forKey: commitBaselineKey)
    }

    private func loadSelectedRepositories() -> Set<String> {
        let repos = UserDefaults.standard.stringArray(forKey: AppDefaultsKeys.githubSelectedRepoNames) ?? []
        return Set(repos)
    }

    private func deduplicate(_ notifications: [WorkNotification]) -> [WorkNotification] {
        var seenIDs: Set<String> = []
        var seenURLs: Set<String> = []
        var result: [WorkNotification] = []

        for notification in notifications {
            if seenIDs.contains(notification.id) { continue }
            if let urlString = notification.url?.absoluteString, seenURLs.contains(urlString) { continue }

            seenIDs.insert(notification.id)
            if let urlString = notification.url?.absoluteString {
                seenURLs.insert(urlString)
            }
            result.append(notification)
        }

        return result
    }
}
