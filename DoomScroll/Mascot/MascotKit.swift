import SwiftUI

// Unified mood vocabulary. Replaces SquareEyesExpression throughout the app.
// Any mascot implementation interprets these moods in its own way.
enum MascotMood: String, Equatable, CaseIterable {
    case idle           // Default resting state
    case happy          // Positive feedback, streak going
    case proud          // Achievement milestone
    case concerned      // Warning / needs attention
    case sleepy         // Overrides exhausted, depleted
    case disappointed   // Streak broken
    case celebrating    // Major milestone — 30-day streak, first session, etc.
}

// MARK: - Protocol

// The only interface the app uses to talk to a mascot.
// Conform to this to swap in a new character or seasonal variant.
protocol MascotStyle {
    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> AnyView
    func triggerReaction()
}

extension MascotStyle {
    func triggerReaction() {}
}

// MARK: - Environment

private struct MascotStyleKey: EnvironmentKey {
    static let defaultValue: any MascotStyle = SquareEyesMascot()
}

extension EnvironmentValues {
    var mascotStyle: any MascotStyle {
        get { self[MascotStyleKey.self] }
        set { self[MascotStyleKey.self] = newValue }
    }
}

extension View {
    // Injects a mascot into the entire view subtree.
    // Called once at the root (DoomScrollApp). All MascotViews below pick it up.
    func mascot(_ style: any MascotStyle) -> some View {
        environment(\.mascotStyle, style)
    }
}

// MARK: - Slot view

// The only mascot view call sites should use. Never reference SquareEyesView directly.
// Swap the whole character app-wide by changing the .mascot() injection at the root.
struct MascotView: View {
    var mood: MascotMood = .idle
    var size: CGFloat = 120
    var animated: Bool = true

    @Environment(\.mascotStyle) private var style

    var body: some View {
        style.view(mood: mood, size: size, animated: animated)
    }
}

// MARK: - Seasonal themes
//
// Seasonal layers live entirely inside the .riv file.
// Swift sends a Season number input; Rive shows/hides the matching layer.
// Add new cases here + the corresponding layer in the Rive artboard.

enum SeasonalTheme: CaseIterable {
    case winter     // Dec–Jan: snow, cold-toned accessories
    case halloween  // Oct 15–31: pumpkin, bats, orange tint
    case spring     // Mar 20 – Apr: petals, warm blush
    case worldCup   // Jun–Jul: football, national colours

    // Returns the active theme based on today's date, or nil when none applies.
    static var current: SeasonalTheme? {
        let cal   = Calendar.current
        let month = cal.component(.month, from: Date())
        let day   = cal.component(.day,   from: Date())
        switch (month, day) {
        case (12, _), (1, 1...6):    return .winter
        case (10, 15...31):          return .halloween
        case (3, 20...31), (4, _):   return .spring
        case (6, _), (7, 1...15):    return .worldCup
        default:                     return nil
        }
    }

    // Sent as the "Season" Number input to the Rive state machine.
    // 0 is reserved for "no season" (nil). Keep in sync with DesignerBriefing.md.
    var riveValue: Float {
        switch self {
        case .winter:   return 1
        case .halloween: return 2
        case .spring:   return 3
        case .worldCup: return 4
        }
    }

    var displayName: String {
        switch self {
        case .winter:   return "Winter"
        case .halloween: return "Halloween"
        case .spring:   return "Spring"
        case .worldCup: return "World Cup"
        }
    }

    var emoji: String {
        switch self {
        case .winter:   return "❄️"
        case .halloween: return "🎃"
        case .spring:   return "🌸"
        case .worldCup: return "⚽"
        }
    }
}
