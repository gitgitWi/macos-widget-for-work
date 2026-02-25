import Foundation

struct ServiceConfig: Codable, Sendable {
    var isEnabled: Bool
    var isAuthenticated: Bool
}
