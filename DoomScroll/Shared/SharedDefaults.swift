import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

// All keys shared between the main app and extensions via App Groups.
enum SharedDefaults {
    static let suiteName = "group.com.doomscroll"

    // `var` rather than `let` so unit tests can inject a clean, non-App-Group
    // UserDefaults before each test. Production code never reassigns this.
    // Falls back to .standard (with an assertionFailure in debug) if the App Group
    // entitlement is misconfigured so extensions fail loudly during development.
    static var store: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            assertionFailure("App Group '\(suiteName)' not configured in entitlements")
            return .standard
        }
        return defaults
    }()

    enum Key {
        static let userProfile        = "userProfile"
        static let overrideLog        = "overrideLog"
        static let shieldState        = "shieldState"
        static let dailyBudgets       = "dailyBudgets"
        // Widget-readable snapshot (written by main app, read by widget)
        static let currentStreak      = "currentStreak"
        static let reclaimedPercent   = "reclaimedPercent"
        static let overridesLeftTotal = "overridesLeftTotal"
        // Streak tracking
        static let streakCount        = "streakCount"
        static let lastStreakDate     = "lastStreakDate"
        static let streakBrokenToday  = "streakBrokenToday"
        static let bestStreak         = "bestStreak"
    }

    // Writes the widget snapshot. Call from the main app whenever stats change.
    static func updateWidgetSnapshot(streak: Int, reclaimedPercent: Int, overridesLeft: Int) {
        store.set(streak,          forKey: Key.currentStreak)
        store.set(reclaimedPercent, forKey: Key.reclaimedPercent)
        store.set(overridesLeft,   forKey: Key.overridesLeftTotal)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

// Conversation state persisted so the shield extension knows which step it's on.
struct ShieldConversationState: Codable {
    var step: ConversationStep = .impact
    var sessionBudgetSeconds: TimeInterval = 0

    enum ConversationStep: String, Codable {
        case impact       // Show time-spent / relational stake
        case reflection   // AI-generated reflective question
        case commit       // Choose session time limit
    }
}

extension ShieldConversationState {
    static func load(for tokenString: String) -> ShieldConversationState {
        guard
            let data = SharedDefaults.store.data(forKey: SharedDefaults.Key.shieldState + tokenString),
            let state = try? JSONDecoder().decode(ShieldConversationState.self, from: data)
        else { return ShieldConversationState() }
        return state
    }

    func save(for tokenString: String) {
        let data = try? JSONEncoder().encode(self)
        SharedDefaults.store.set(data, forKey: SharedDefaults.Key.shieldState + tokenString)
    }
}
