import Foundation

// All keys shared between the main app and extensions via App Groups.
enum SharedDefaults {
    static let suiteName = "group.com.doomscroll"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    enum Key {
        static let userProfile = "userProfile"
        static let overrideLog = "overrideLog"       // [String: [Date]] appToken -> override timestamps
        static let shieldState = "shieldState"        // [String: ShieldConversationState]
        static let dailyBudgets = "dailyBudgets"      // [String: TimeInterval] appToken -> seconds
    }
}

// Conversation state persisted so the shield extension knows which step it's on.
struct ShieldConversationState: Codable {
    var step: ConversationStep = .impact
    var sessionBudgetSeconds: TimeInterval = 0
    var overridesToday: Int = 0

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
