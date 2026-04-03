import Foundation

/// UserDefaults Manager for app preferences
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private init() {}

    // MARK: - Keys

    private enum Keys {
        static let serverURL = "serverURL"
        static let autoSyncEnabled = "autoSyncEnabled"
        static let syncHour = "syncHour"
        static let lastSyncTime = "lastSyncTime"
        static let username = "username"
    }

    // MARK: - Properties

    var serverURL: String {
        get { UserDefaults.standard.string(forKey: Keys.serverURL) ?? "http://localhost:3000" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.serverURL) }
    }

    var autoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoSyncEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoSyncEnabled) }
    }

    var syncHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Keys.syncHour)
            return stored == 0 ? 10 : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.syncHour) }
    }

    var lastSyncTime: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastSyncTime) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastSyncTime) }
    }

    var username: String? {
        get { UserDefaults.standard.string(forKey: Keys.username) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.username) }
    }

    // MARK: - Reset

    func reset() {
        UserDefaults.standard.removeObject(forKey: Keys.serverURL)
        UserDefaults.standard.removeObject(forKey: Keys.autoSyncEnabled)
        UserDefaults.standard.removeObject(forKey: Keys.lastSyncTime)
    }
}
