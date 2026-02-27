import Foundation

// MARK: - GitHub Notifications API Response

struct GitHubNotification: Decodable, Sendable {
    let id: String
    let unread: Bool
    let reason: String
    let updated_at: String
    let subject: GitHubSubject
    let repository: GitHubRepository
    let url: String?

    struct GitHubSubject: Decodable, Sendable {
        let title: String
        let url: String?
        let type: String // "PullRequest", "Issue", "Release", "Discussion", etc.
    }

    struct GitHubRepository: Decodable, Sendable {
        let full_name: String
        let html_url: String
    }

    /// Convert subject URL (api.github.com) to browser URL (github.com)
    var htmlURL: URL? {
        // API URL: https://api.github.com/repos/owner/repo/pulls/42
        // HTML URL: https://github.com/owner/repo/pull/42
        guard let apiURL = subject.url else { return nil }
        return URL(string:
            apiURL
                .replacingOccurrences(of: "api.github.com/repos", with: "github.com")
                .replacingOccurrences(of: "/pulls/", with: "/pull/")
                .replacingOccurrences(of: "/issues/", with: "/issues/")
                .replacingOccurrences(of: "/releases/", with: "/releases/")
        )
    }

    var iconName: String {
        switch subject.type {
        case "PullRequest": return "arrow.triangle.pull"
        case "Issue": return "exclamationmark.circle"
        case "Release": return "tag"
        case "Discussion": return "bubble.left.and.bubble.right"
        default: return "arrow.triangle.branch"
        }
    }

    var priority: NotificationPriority {
        switch reason {
        case "review_requested", "assign", "security_alert": return .high
        case "mention", "team_mention": return .high
        case "ci_activity": return .low
        default: return .normal
        }
    }

    var parsedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: updated_at) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: updated_at) ?? Date()
    }
}

// MARK: - GitHub Search API (PR/Issue)

struct GitHubSearchResponse: Decodable, Sendable {
    let items: [GitHubSearchItem]
}

struct GitHubSearchItem: Decodable, Sendable {
    let node_id: String
    let number: Int
    let title: String
    let html_url: String
    let repository_url: String
    let updated_at: String
    let pull_request: PullRequestMarker?

    struct PullRequestMarker: Decodable, Sendable {
        let url: String?
    }

    var htmlURL: URL? { URL(string: html_url) }

    var parsedUpdatedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: updated_at) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: updated_at) ?? Date()
    }

    var repositoryFullName: String {
        // API URL: https://api.github.com/repos/owner/repo
        // Value needed: owner/repo
        guard let range = repository_url.range(of: "/repos/") else {
            return "Unknown repository"
        }
        return String(repository_url[range.upperBound...])
    }
}

// MARK: - GitHub Repositories API

struct GitHubRepositorySummary: Decodable, Sendable {
    let full_name: String
    let html_url: String
    let default_branch: String
    let fork: Bool
    let pushed_at: String?

    var parsedPushedDate: Date {
        guard let pushed_at else { return .distantPast }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: pushed_at) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: pushed_at) ?? .distantPast
    }
}

// MARK: - GitHub Commits API

struct GitHubCommit: Decodable, Sendable {
    let sha: String
    let html_url: String
    let commit: CommitPayload

    struct CommitPayload: Decodable, Sendable {
        let message: String
        let author: AuthorPayload?

        struct AuthorPayload: Decodable, Sendable {
            let name: String?
            let date: String?
        }
    }

    var htmlURL: URL? { URL(string: html_url) }

    var parsedAuthorDate: Date {
        guard let dateString = commit.author?.date else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }

    var shortMessage: String {
        commit.message
            .split(separator: "\n", maxSplits: 1)
            .first
            .map(String.init) ?? "New commit"
    }
}
