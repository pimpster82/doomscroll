import Foundation

// Tracks daily override use per app. Max 2 overrides per app per calendar day.
struct OverrideTracker {
    static let maxOverridesPerDay = 2

    private static var log: [String: [Date]] {
        get {
            guard
                let data = SharedDefaults.store.data(forKey: SharedDefaults.Key.overrideLog),
                let log = try? JSONDecoder().decode([String: [Date]].self, from: data)
            else { return [:] }
            return log
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            SharedDefaults.store.set(data, forKey: SharedDefaults.Key.overrideLog)
        }
    }

    static func overridesToday(for tokenString: String) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let timestamps = log[tokenString] ?? []
        return timestamps.filter { $0 >= today }.count
    }

    static func canOverride(for tokenString: String) -> Bool {
        overridesToday(for: tokenString) < maxOverridesPerDay
    }

    static func recordOverride(for tokenString: String) {
        var current = log
        var timestamps = current[tokenString] ?? []
        // Prune timestamps older than today to keep storage small.
        let today = Calendar.current.startOfDay(for: Date())
        timestamps = timestamps.filter { $0 >= today }
        timestamps.append(Date())
        current[tokenString] = timestamps
        log = current
    }

    static func remainingToday(for tokenString: String) -> Int {
        max(0, maxOverridesPerDay - overridesToday(for: tokenString))
    }
}
