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
        return (log[tokenString] ?? []).filter { $0 >= today }.count
    }

    static func canOverride(for tokenString: String) -> Bool {
        overridesToday(for: tokenString) < maxOverridesPerDay
    }

    // Non-atomic record — kept for callers that already checked canOverride separately.
    static func recordOverride(for tokenString: String) {
        let today = Calendar.current.startOfDay(for: Date())
        var current = log
        var timestamps = (current[tokenString] ?? []).filter { $0 >= today }
        timestamps.append(Date())
        current[tokenString] = timestamps
        log = current
        if timestamps.count >= maxOverridesPerDay { breakStreak() }
        updateWidgetSnapshot()
    }

    // Atomic check-and-record. Use at commit time to close the TOCTOU window between
    // the initial canOverride check (at impact screen) and the actual record (at commit).
    // Returns false if the limit was hit by a concurrent override — caller should .close.
    static func attemptOverride(for tokenString: String) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        var current = log
        var timestamps = (current[tokenString] ?? []).filter { $0 >= today }
        guard timestamps.count < maxOverridesPerDay else { return false }
        timestamps.append(Date())
        current[tokenString] = timestamps
        log = current
        if timestamps.count >= maxOverridesPerDay { breakStreak() }
        updateWidgetSnapshot()
        return true
    }

    static func remainingToday(for tokenString: String) -> Int {
        max(0, maxOverridesPerDay - overridesToday(for: tokenString))
    }

    // Total overrides used today across all tracked apps (for dashboard dots + widget).
    static func totalOverridesToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return log.values.reduce(0) { $0 + $1.filter { $0 >= today }.count }
    }

    // MARK: - Streak

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func todayString() -> String {
        dayFormatter.string(from: Date())
    }

    // Call at the start of each calendar day (DeviceActivityMonitor.intervalDidStart).
    // If yesterday had no exhausted overrides, increments the streak.
    static func advanceStreakForNewDay() {
        let today = todayString()
        guard SharedDefaults.store.string(forKey: SharedDefaults.Key.lastStreakDate) != today else { return }

        let wasBroken = SharedDefaults.store.bool(forKey: SharedDefaults.Key.streakBrokenToday)
        if !wasBroken {
            let newStreak = SharedDefaults.store.integer(forKey: SharedDefaults.Key.streakCount) + 1
            SharedDefaults.store.set(newStreak, forKey: SharedDefaults.Key.streakCount)
            let best = max(newStreak, SharedDefaults.store.integer(forKey: SharedDefaults.Key.bestStreak))
            SharedDefaults.store.set(best, forKey: SharedDefaults.Key.bestStreak)
        }
        SharedDefaults.store.set(today, forKey: SharedDefaults.Key.lastStreakDate)
        SharedDefaults.store.set(false, forKey: SharedDefaults.Key.streakBrokenToday)
    }

    static func currentStreak() -> Int {
        SharedDefaults.store.integer(forKey: SharedDefaults.Key.streakCount)
    }

    static func bestStreak() -> Int {
        SharedDefaults.store.integer(forKey: SharedDefaults.Key.bestStreak)
    }

    // Immediate streak reset. Called when all overrides are exhausted for any app.
    private static func breakStreak() {
        SharedDefaults.store.set(0,    forKey: SharedDefaults.Key.streakCount)
        SharedDefaults.store.set(true, forKey: SharedDefaults.Key.streakBrokenToday)
        SharedDefaults.store.set(todayString(), forKey: SharedDefaults.Key.lastStreakDate)
    }

    // MARK: - Widget

    private static func updateWidgetSnapshot() {
        let totalOverridesLeft = max(0, maxOverridesPerDay * 2 - totalOverridesToday())
        SharedDefaults.updateWidgetSnapshot(
            streak: currentStreak(),
            reclaimedPercent: SharedDefaults.store.integer(forKey: SharedDefaults.Key.reclaimedPercent),
            overridesLeft: totalOverridesLeft
        )
    }
}
