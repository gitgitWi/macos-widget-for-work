import Foundation

@Observable
final class SettingsStore: @unchecked Sendable {
    var serviceConfigs: [ServiceType: ServiceConfig] = [:]
    var pollIntervalSeconds: Int = 60

    private let defaults = UserDefaults.standard
    private let configKey = "serviceConfigs"
    private let pollKey = "pollIntervalSeconds"

    init() {
        loadConfigs()
    }

    func isServiceEnabled(_ type: ServiceType) -> Bool {
        serviceConfigs[type]?.isEnabled ?? false
    }

    func isAuthenticated(_ type: ServiceType) -> Bool {
        serviceConfigs[type]?.isAuthenticated ?? false
    }

    func toggleVisibility(for type: ServiceType) {
        serviceConfigs[type]?.isEnabled.toggle()
        saveConfigs()
    }

    func markAuthenticated(_ type: ServiceType, _ authenticated: Bool) {
        if serviceConfigs[type] == nil {
            serviceConfigs[type] = ServiceConfig(isEnabled: true, isAuthenticated: authenticated)
        } else {
            serviceConfigs[type]?.isAuthenticated = authenticated
            if authenticated {
                serviceConfigs[type]?.isEnabled = true
            }
        }
        saveConfigs()
    }

    func setPollInterval(_ seconds: Int) {
        pollIntervalSeconds = seconds
        defaults.set(seconds, forKey: pollKey)
    }

    private func loadConfigs() {
        if let data = defaults.data(forKey: configKey),
           let configs = try? JSONDecoder().decode([ServiceType: ServiceConfig].self, from: data)
        {
            self.serviceConfigs = configs
        } else {
            for type in ServiceType.allCases {
                serviceConfigs[type] = ServiceConfig(isEnabled: false, isAuthenticated: false)
            }
        }

        let savedPoll = defaults.integer(forKey: pollKey)
        if savedPoll > 0 {
            pollIntervalSeconds = savedPoll
        }
    }

    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(serviceConfigs) {
            defaults.set(data, forKey: configKey)
        }
    }
}
