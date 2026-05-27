import Foundation
import ManagedSettings

struct FocusSession: Codable {
    var focusAppName: String
    var durationSeconds: TimeInterval
    var startDate: Date
    var state: State
    var earlyExitAttempts: Int = 0

    enum State: String, Codable {
        case active
        case endedNaturally
        case endedEarly
    }

    var endDate: Date { startDate.addingTimeInterval(durationSeconds) }
    var isActive: Bool { state == .active && Date() < endDate }
    var remainingSeconds: TimeInterval { max(0, endDate.timeIntervalSince(Date())) }
    var elapsedSeconds: TimeInterval { min(durationSeconds, Date().timeIntervalSince(startDate)) }
    var progressFraction: Double { min(1, elapsedSeconds / durationSeconds) }

    // Friction adapted for focus context — protects the session, not an addiction intervention.
    var earlyExitPrompt: EarlyExitPrompt {
        let elapsedMin = Int(elapsedSeconds / 60)
        let remainingMin = Int(remainingSeconds / 60)

        return EarlyExitPrompt(
            impactLine: "You're \(elapsedMin) min into your \(Int(durationSeconds / 60))-min focus session. \(remainingMin) min left.",
            reflectionQuestion: reflectionQuestion,
            confirmLabel: "End focus session",
            continueLabel: "Keep focusing"
        )
    }

    private var reflectionQuestion: String {
        switch earlyExitAttempts {
        case 0:
            return "What's pulling you away right now — something urgent, or just friction?"
        case 1:
            return "You already tried to end this once. Is what's calling you actually more important than your focus?"
        default:
            return "This is your third attempt to break focus. Is this session still worth defending?"
        }
    }
}

struct EarlyExitPrompt {
    let impactLine: String
    let reflectionQuestion: String
    let confirmLabel: String
    let continueLabel: String
}

// MARK: - Persistence

extension FocusSession {
    static let storageKey = "activeFocusSession"

    static func loadActive() -> FocusSession? {
        guard
            let data = SharedDefaults.store.data(forKey: storageKey),
            let session = try? JSONDecoder().decode(FocusSession.self, from: data),
            session.isActive
        else { return nil }
        return session
    }

    func save() {
        let data = try? JSONEncoder().encode(self)
        SharedDefaults.store.set(data, forKey: FocusSession.storageKey)
    }

    static func clear() {
        SharedDefaults.store.removeObject(forKey: storageKey)
    }
}

// Common focus durations.
enum FocusDuration: CaseIterable {
    case quick, standard, deep, custom(TimeInterval)

    var seconds: TimeInterval {
        switch self {
        case .quick:    return 25 * 60
        case .standard: return 45 * 60
        case .deep:     return 90 * 60
        case .custom(let s): return s
        }
    }

    var label: String {
        switch self {
        case .quick:    return "25 min"
        case .standard: return "45 min"
        case .deep:     return "90 min"
        case .custom:   return "Custom"
        }
    }

    static var allCases: [FocusDuration] { [.quick, .standard, .deep] }
}
