import Foundation

protocol SprintStoring {
    func load() -> Sprint?
    func save(_ sprint: Sprint?)
}

/// Persists the active sprint so an in-progress session survives app
/// relaunches. Elapsed time is derived from absolute timestamps inside
/// `Sprint`, so a restored running sprint keeps counting across the gap.
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
