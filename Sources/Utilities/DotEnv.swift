import Foundation

enum DotEnv {
    // Safe: written once at startup before any concurrent reads
    private nonisolated(unsafe) static var loaded: [String: String] = [:]

    /// Load .env file from known locations (first found wins)
    static func load() {
        let searchPaths = [
            // 1. Current working directory (development: swift build && .build/debug/WorkWidget)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".env"),
            // 2. User config directory (production: open /Applications/WorkWidget.app)
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/workwidget/.env"),
        ]

        for path in searchPaths {
            if let contents = try? String(contentsOf: path, encoding: .utf8) {
                parse(contents)
                return
            }
        }
    }

    /// Get a value by key — checks loaded .env first, then process environment
    static func get(_ key: String) -> String? {
        loaded[key] ?? ProcessInfo.processInfo.environment[key]
    }

    /// Get a value or return a fallback
    static func get(_ key: String, default fallback: String) -> String {
        get(key) ?? fallback
    }

    private static func parse(_ contents: String) {
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\""))
                || (value.hasPrefix("'") && value.hasSuffix("'"))
            {
                value = String(value.dropFirst().dropLast())
            }

            loaded[key] = value
        }
    }
}
