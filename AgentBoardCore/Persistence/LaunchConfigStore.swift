import Foundation

/// UserDefaults-backed persistence for `SessionLauncher.LaunchConfig`, keyed by
/// the generated tmux session name. Lets `SessionLauncher` offer "Restart" only
/// for sessions it launched itself — foreign/discovered sessions have no entry.
///
/// Deliberately a plain struct (not an actor, unlike `SettingsRepository`):
/// `SessionLauncher` is `@MainActor`-isolated and is the only caller, and
/// `canRelaunch(sessionName:)` must stay synchronous per its `-> Bool` contract.
public struct LaunchConfigStore {
    private enum Keys {
        static let configs = "modern.agentboard.sessionLauncher.launchConfigs"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func config(forSessionName sessionName: String) -> SessionLauncher.LaunchConfig? {
        load()[sessionName]
    }

    public func store(_ config: SessionLauncher.LaunchConfig, forSessionName sessionName: String) {
        var all = load()
        all[sessionName] = config
        save(all)
    }

    public func remove(sessionName: String) {
        var all = load()
        all.removeValue(forKey: sessionName)
        save(all)
    }

    private func load() -> [String: SessionLauncher.LaunchConfig] {
        guard let data = defaults.data(forKey: Keys.configs),
              let decoded = try? JSONDecoder().decode([String: SessionLauncher.LaunchConfig].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ configs: [String: SessionLauncher.LaunchConfig]) {
        guard let encoded = try? JSONEncoder().encode(configs) else { return }
        defaults.set(encoded, forKey: Keys.configs)
    }
}
