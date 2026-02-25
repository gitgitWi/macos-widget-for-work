import Foundation

/// Per-service OAuth configuration.
/// Client IDs/secrets should be set before use (loaded from config or environment).
struct OAuthConfig: Sendable {
    let authorizeURL: String
    let tokenURL: String
    let clientID: String
    let clientSecret: String
    let scopes: String
    let callbackScheme: String

    var redirectURI: String {
        "\(callbackScheme)://oauth/callback"
    }

    // MARK: - Factory

    static func github(clientID: String, clientSecret: String) -> OAuthConfig {
        OAuthConfig(
            authorizeURL: "https://github.com/login/oauth/authorize",
            tokenURL: "https://github.com/login/oauth/access_token",
            clientID: clientID,
            clientSecret: clientSecret,
            scopes: "notifications,read:user",
            callbackScheme: "workwidget"
        )
    }

    static func microsoft(clientID: String, clientSecret: String = "") -> OAuthConfig {
        OAuthConfig(
            authorizeURL: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
            tokenURL: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            clientID: clientID,
            clientSecret: clientSecret,
            scopes: "Chat.Read ChannelMessage.Read.All offline_access",
            callbackScheme: "workwidget"
        )
    }

    static func notion(clientID: String, clientSecret: String) -> OAuthConfig {
        OAuthConfig(
            authorizeURL: "https://api.notion.com/v1/oauth/authorize",
            tokenURL: "https://api.notion.com/v1/oauth/token",
            clientID: clientID,
            clientSecret: clientSecret,
            scopes: "",
            callbackScheme: "workwidget"
        )
    }

    static func google(clientID: String, clientSecret: String = "") -> OAuthConfig {
        OAuthConfig(
            authorizeURL: "https://accounts.google.com/o/oauth2/v2/auth",
            tokenURL: "https://oauth2.googleapis.com/token",
            clientID: clientID,
            clientSecret: clientSecret,
            scopes: "https://www.googleapis.com/auth/calendar.readonly",
            callbackScheme: "workwidget"
        )
    }
}
