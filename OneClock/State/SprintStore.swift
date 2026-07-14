import Foundation

protocol SprintStoring {
    func load() -> Sprint?
    func save(_ sprint: Sprint?)
}

/// Persists recovery snapshots so an in-progress session survives relaunches.
/// The controller stores running phases as paused checkpoints, preventing app
/// downtime from being counted as focused time.
struct UserDefaultsSprintStore: SprintStoring {
    static let defaultKey = "activeSprint"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = UserDefaultsSprintStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Sprint? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(Sprint.self, from: data)
    }

    func save(_ sprint: Sprint?) {
        guard let sprint, let data = try? JSONEncoder().encode(sprint) else {
            defaults.removeObject(forKey: key)
            return
        }

        defaults.set(data, forKey: key)
    }
}
