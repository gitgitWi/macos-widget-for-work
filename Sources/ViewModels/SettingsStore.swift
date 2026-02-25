import Foundation

@Observable
final class SettingsStore: @unchecked Sendable {
    var serviceConfigs: [ServiceType: ServiceConfig] = [:]
    var pollIntervalSeconds: Int = 60
    var backgroundOpacity: Double = 1.0
    var calendarLookaheadHours: Int = 24

    private let defaults = UserDefaults.standard
    private let configKey = "serviceConfigs"
    private let pollKey = "pollIntervalSeconds"
    private let opacityKey = "backgroundOpacity"
    private let lookaheadKey = "calendarLookaheadHours"

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

    func setBackgroundOpacity(_ value: Double) {
        backgroundOpacity = max(0.1, min(1.0, value))
        defaults.set(backgroundOpacity, forKey: opacityKey)
    }

    func setCalendarLookahead(_ hours: Int) {
        calendarLookaheadHours = max(1, min(72, hours))
        defaults.set(calendarLookaheadHours, forKey: lookaheadKey)
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

        let savedOpacity = defaults.double(forKey: opacityKey)
        if savedOpacity > 0 {
            backgroundOpacity = savedOpacity
        }

        let savedLookahead = defaults.integer(forKey: lookaheadKey)
        if savedLookahead > 0 {
            calendarLookaheadHours = savedLookahead
        }
    }

    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(serviceConfigs) {
            defaults.set(data, forKey: configKey)
        }
    }
}
