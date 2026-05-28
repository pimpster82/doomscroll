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

// MARK: - Seasonal decorator

// Wraps any base mascot with a seasonal overlay layered on top.
// The overlay is purely additive — it never touches the base character's internals.
struct SeasonalOverlay: MascotStyle {
    let base: any MascotStyle
    let theme: SeasonalTheme

    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> AnyView {
        AnyView(
            ZStack {
                base.view(mood: mood, size: size, animated: animated)
                theme.overlayView(size: size, animated: animated)
            }
        )
    }

    func triggerReaction() { base.triggerReaction() }
}

// MARK: - Seasonal themes

enum SeasonalTheme: CaseIterable {
    case winter     // Snowflake + Santa hat, cool iris tint
    case halloween  // Pumpkin accessory, orange iris tint, bat particles
    case spring     // Floating flower petals, warm blush boost

    // Returns the active theme based on today's date, or nil when no theme applies.
    static var current: SeasonalTheme? {
        let cal   = Calendar.current
        let month = cal.component(.month, from: Date())
        let day   = cal.component(.day,   from: Date())
        switch (month, day) {
        case (12, _), (1, 1...6):    return .winter
        case (10, 15...31):          return .halloween
        case (3, 20...31), (4, _):   return .spring
        default:                     return nil
        }
    }

    @ViewBuilder
    func overlayView(size: CGFloat, animated: Bool) -> some View {
        switch self {
        case .winter:    WinterOverlayView(size: size, animated: animated)
        case .halloween: HalloweenOverlayView(size: size, animated: animated)
        case .spring:    SpringOverlayView(size: size, animated: animated)
        }
    }
}

// MARK: - Seasonal overlay stubs
// Each is a self-contained View. Replace bodies with real particle/accessory art.

struct WinterOverlayView: View {
    let size: CGFloat
    let animated: Bool
    var body: some View {
        Image(systemName: "snowflake")
            .font(.system(size: size * 0.24, weight: .light))
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .cyan.opacity(0.6), radius: 4)
            .offset(x: size * 0.18, y: -size * 0.64)
    }
}

struct HalloweenOverlayView: View {
    let size: CGFloat
    let animated: Bool
    var body: some View {
        Text("🎃")
            .font(.system(size: size * 0.26))
            .offset(x: size * 0.14, y: -size * 0.62)
    }
}

struct SpringOverlayView: View {
    let size: CGFloat
    let animated: Bool
    var body: some View {
        Text("🌸")
            .font(.system(size: size * 0.22))
            .offset(x: size * 0.16, y: -size * 0.62)
    }
}
