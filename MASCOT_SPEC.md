# Square Eyes — Mascot System Spec

## Vision

The mascot is not a component — it is a **slot**. Any view in the app that shows a mascot uses the slot. What sits in the slot can be swapped globally: different character, seasonal skin, A/B variant, special event. Call sites never change.

Seasonal specials (Winter Mode, Halloween, anniversary) are **decorators** layered on top of any base mascot — not separate implementations. A Santa hat works on Square Eyes today and on any future character automatically.

---

## What's wrong with the current implementation

The current SquareEyes is hardwired into every view. The specific problems:

- **Baked in.** `SquareEyesView` is imported directly at every call site. Swapping the character requires touching every screen.
- **Flat and lifeless.** Uniform mint fill, no shadow, no gradient, no inner glow.
- **Eyes only.** No mouth, no body weight, no squash/stretch.
- **Fragile animation.** Timer + DispatchQueue.asyncAfter for blinking is unpredictable and fights expression transitions.
- **Tightly coupled expressions.** Adding one new expression means editing 5+ switch statements.
- **Magic multipliers.** `size * 0.28`, `size * 0.59` everywhere — no semantic structure.

---

## Architecture: The Mascot Slot System

### Layer 1 — The protocol (in `DoomScroll/Mascot/MascotKit.swift`)

```swift
// Everything the app knows about a mascot. Nothing more.
protocol MascotStyle {
    // The view the mascot renders for a given emotional state.
    @ViewBuilder
    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> any View

    // Optional: called when a significant event happens (override recorded,
    // session ends). The mascot can react however it likes.
    func triggerReaction()
}

// Unified mood vocabulary — richer than the current expression enum,
// so future characters can interpret moods in their own way.
enum MascotMood: String, CaseIterable {
    case idle           // Default resting state
    case happy          // Positive feedback, streak going
    case proud          // Achievement milestone
    case concerned      // Warning / needs attention
    case sleepy         // Overrides exhausted
    case disappointed   // Streak broken
    case celebrating    // Major milestone (30-day streak etc.)
}
```

### Layer 2 — Environment injection (one line per screen)

```swift
// EnvironmentKey so any view can access the current mascot.
struct MascotStyleKey: EnvironmentKey {
    static let defaultValue: any MascotStyle = SquareEyesMascot()
}

extension EnvironmentValues {
    var mascotStyle: any MascotStyle {
        get { self[MascotStyleKey.self] }
        set { self[MascotStyleKey.self] = newValue }
    }
}

// Convenience view modifier.
extension View {
    func mascot(_ style: any MascotStyle) -> some View {
        environment(\.mascotStyle, style)
    }
}
```

### Layer 3 — The public slot view (replaces all direct SquareEyesView usage)

```swift
// This is what every call site uses. Never SquareEyesView directly.
struct MascotView: View {
    var mood: MascotMood = .idle
    var size: CGFloat = 120
    var animated: Bool = true

    @Environment(\.mascotStyle) private var style

    var body: some View {
        AnyView(style.view(mood: mood, size: size, animated: animated))
    }
}
```

### Layer 4 — Concrete mascot: SquareEyesMascot

```swift
// Lives in DoomScroll/Mascot/SquareEyes/SquareEyesMascot.swift
// The app knows nothing about this type except that it conforms to MascotStyle.
final class SquareEyesMascot: MascotStyle {
    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> any View {
        SquareEyesRenderer(mood: mood, size: size, animated: animated)
    }

    func triggerReaction() {
        // Post a notification or update @Observable state that
        // SquareEyesRenderer listens to for the squash/stretch sequence.
        NotificationCenter.default.post(name: .mascotReactionTriggered, object: nil)
    }
}
```

### Layer 5 — Decorator: SeasonalOverlay

```swift
// Wraps ANY base mascot. Seasonal content is additive — layered on top.
// Seasonal overlays never touch the base mascot's internals.
struct SeasonalOverlay: MascotStyle {
    let base: any MascotStyle
    let theme: SeasonalTheme

    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> any View {
        ZStack {
            AnyView(base.view(mood: mood, size: size, animated: animated))
            theme.overlay(size: size, animated: animated)
        }
    }

    func triggerReaction() { base.triggerReaction() }
}

enum SeasonalTheme {
    case winter         // Snowflake particles, Santa hat, cool color tint on iris
    case halloween      // Tiny pumpkin accessory, orange iris tint, bat particles
    case anniversary    // Confetti burst on reaction trigger
    case spring         // Floating flower petals, warmer cheek blush

    @ViewBuilder
    func overlay(size: CGFloat, animated: Bool) -> some View {
        switch self {
        case .winter:   WinterOverlayView(size: size, animated: animated)
        case .halloween: HalloweenOverlayView(size: size, animated: animated)
        case .anniversary: AnniversaryOverlayView(size: size, animated: animated)
        case .spring:   SpringOverlayView(size: size, animated: animated)
        }
    }
}
```

### App-level wiring (one place)

```swift
// In DoomScrollApp.swift — the only place that knows which mascot is active.
var body: some Scene {
    WindowGroup {
        RootView()
            .mascot(activeMascot)
    }
}

private var activeMascot: any MascotStyle {
    let base = SquareEyesMascot()
    if let theme = SeasonalTheme.current {   // checks date
        return SeasonalOverlay(base: base, theme: theme)
    }
    return base
}
```

---

## File structure

```
DoomScroll/Mascot/
  MascotKit.swift               ← protocol, MascotMood, EnvironmentKey, MascotView, SeasonalOverlay
  SeasonalTheme.swift           ← SeasonalTheme enum, date-range logic, .current computed property

  SquareEyes/
    SquareEyesMascot.swift      ← MascotStyle conformance + triggerReaction
    SquareEyesRenderer.swift    ← the actual drawing code (currently SquareEyesView.swift)
    SquareEyesPose.swift        ← pose lookup table (MascotMood → geometry values)
    MascotMetrics.swift         ← all proportions derived from `size`, no magic multipliers

  Seasonal/
    WinterOverlayView.swift     ← snowflakes + hat
    HalloweenOverlayView.swift  ← pumpkin + bats
    AnniversaryOverlayView.swift ← confetti
    SpringOverlayView.swift     ← petals
```

---

## Call site migration

Every call site changes from:
```swift
SquareEyesView(expression: .happy, size: 64)
```
to:
```swift
MascotView(mood: .happy, size: 64)
```

That's the entire migration. No other changes needed at call sites.

**Current call sites to update:**

| File | Current | After |
|---|---|---|
| `DashboardView.swift` | `SquareEyesView(expression: mascotExpression, size: 64)` | `MascotView(mood: mascotMood, size: 64)` |
| `FocusModeView.swift` | `SquareEyesView(expression: mascotExpression, size: 64)` | `MascotView(mood: mascotMood, size: 64)` |
| `ActiveFocusView.swift` | `SquareEyesView(expression: ..., size: 72)` | `MascotView(mood: ..., size: 72)` |
| `OnboardingView.swift` | `SquareEyesView(expression: .concerned, size: 110)` | `MascotView(mood: .concerned, size: 110)` |
| `AuthorizationView.swift` | `SquareEyesView(expression: .concerned, size: 120)` | `MascotView(mood: .concerned, size: 120)` |
| `PaywallView.swift` | `SquareEyesView(expression: mascotExpression, size: 100)` | `MascotView(mood: mascotMood, size: 100)` |
| `DoomScrollWidget.swift` | `SquareEyesView(expression: ..., size: 70, animated: false)` | `MascotView(mood: ..., size: 70, animated: false)` |

---

## Adding a future character

To ship an entirely different mascot (e.g., a drawn illustrated character via Rive):

1. Create `RiveMascot.swift` conforming to `MascotStyle`
2. `view()` returns a `RiveViewModel`-driven SwiftUI view
3. `triggerReaction()` triggers the Rive state machine event
4. Change one line in `DoomScrollApp.swift`: `.mascot(RiveMascot())`

Zero changes to any screen or widget.

---

## Adding a seasonal special

1. Add a case to `SeasonalTheme`
2. Create the overlay view (a `ZStack` of particles/accessories)
3. Add a date range to `SeasonalTheme.current`
4. Ship. The overlay wraps whatever mascot is active — Square Eyes, future Rive character, anything.

---

## SquareEyesRenderer redesign (the drawing itself)

See the animation and expression specs below. These apply to `SquareEyesRenderer` only — the slot system is agnostic to how any particular mascot renders itself.

---

## Character brief (Square Eyes)

A pale mint blob whose eyes are literal TV screens — glowing blue, square-bezelled, slightly wrong. They've been staring at screens their whole life and feel the cost of it. But they're not sad: they want to help.

They should feel **weighted**, **breathing**, and **inhabited**.

---

## SquareEyesPose — expression lookup table

Replace all switch statements with one struct per mood:

```swift
struct SquareEyesPose {
    var bodyScaleX:    CGFloat = 1.0
    var bodyScaleY:    CGFloat = 1.0
    var eyeOpenness:   CGFloat = 1.0    // 0=closed, 1=fully open
    var irisScale:     CGFloat = 1.0
    var irisOffsetY:   CGFloat = 0      // fraction of eye size
    var useHappyArc:   Bool = false
    var mouthCurve:    CGFloat = 0      // -1 frown → 0 neutral → +1 smile
    var cheekOpacity:  CGFloat = 0
    var armsRaised:    Bool = false
    var eyebrowTilt:   CGFloat = 0      // degrees, applied ±

    static let idle = SquareEyesPose(
        eyeOpenness: 0.60, mouthCurve: -0.15)

    static let happy = SquareEyesPose(
        bodyScaleX: 1.03, bodyScaleY: 0.96,
        eyeOpenness: 1.0, useHappyArc: true,
        mouthCurve: 0.65, cheekOpacity: 0.5, armsRaised: true)

    static let proud = SquareEyesPose(
        bodyScaleX: 0.97, bodyScaleY: 1.04,
        eyeOpenness: 1.0, irisScale: 1.1, useHappyArc: true,
        mouthCurve: 0.85, cheekOpacity: 0.65, armsRaised: true)

    static let concerned = SquareEyesPose(
        bodyScaleY: 1.02,
        eyeOpenness: 1.0, irisScale: 1.05, irisOffsetY: -0.15,
        mouthCurve: -0.2, eyebrowTilt: 10)

    static let sleepy = SquareEyesPose(
        eyeOpenness: 0.18, irisScale: 0.3,
        mouthCurve: 0.05)

    static let disappointed = SquareEyesPose(
        bodyScaleY: 0.97,
        eyeOpenness: 0.45, irisScale: 0.8, irisOffsetY: 0.12,
        mouthCurve: -0.5, eyebrowTilt: 5)

    static let celebrating = SquareEyesPose(
        bodyScaleX: 1.06, bodyScaleY: 0.92,
        eyeOpenness: 1.0, irisScale: 1.2, useHappyArc: true,
        mouthCurve: 1.0, cheekOpacity: 0.8, armsRaised: true)

    static func pose(for mood: MascotMood) -> SquareEyesPose {
        switch mood {
        case .idle:         return .idle
        case .happy:        return .happy
        case .proud:        return .proud
        case .concerned:    return .concerned
        case .sleepy:       return .sleepy
        case .disappointed: return .disappointed
        case .celebrating:  return .celebrating
        }
    }
}
```

---

## Animation system

### Blink — KeyframeAnimator (replaces Timer + asyncAfter)

```
0.00s: eyeOpenness = current
0.07s: eyeOpenness = 0.04   (fast close)
0.13s: eyeOpenness = 0.04   (hold)
0.18s: eyeOpenness = full   (slightly slower open)
Occasionally double-blink: repeat close/open at 0.28–0.42s
```

### Expression transition — coordinated but offset timing

```
Body scale:     SpringKeyframe, stiffness 280, damping 22
Eye openness:   SpringKeyframe, stiffness 350, damping 28   (snappy)
Iris offset:    SpringKeyframe, stiffness 200, damping 20   (floaty)
Mouth curve:    CubicKeyframe, duration 0.25s               (melts)
Arm raise:      SpringKeyframe(bounce: 0.45)
```
Body leads, eyes follow 40ms later, mouth follows 80ms later.

### Idle float — TimelineView

```swift
let y   = sin(t * 0.8) * 3.5   // ±3.5pt, 7.9s period
let rot = sin(t * 0.5) * 1.2   // ±1.2°, 12.6s period
// Two frequencies → Lissajous pattern, never exactly repeats
```

### Reaction squash/stretch — triggerReaction()

```
Phase 1 (impact):    scaleX 1.22, scaleY 0.78   0.08s easeOut
Phase 2 (overshoot): scaleX 0.93, scaleY 1.08   0.18s spring bounce:0.5
Phase 3 (settle):    scaleX 1.00, scaleY 1.00   0.25s spring
```

### Iris glow — mood-responsive depth

```swift
.idle:         shadow(color: mascotIris.opacity(0.30), radius: 4)
.concerned:    shadow(color: Color(hex:"F0A07A").opacity(0.50), radius: 7)  // warm amber
.happy/.proud: shadow(color: mascotIris.opacity(0.70), radius: 8)           // bright blue
.sleepy:       shadow(color: mascotIris.opacity(0.10), radius: 2)
```

---

## Implementation order

1. Create `MascotKit.swift` — protocol, `MascotMood`, `EnvironmentKey`, `MascotView`, `SeasonalOverlay` skeleton
2. Create `SquareEyesMascot.swift` — thin conformance wrapper
3. Wire into `DoomScrollApp.swift` — single `.mascot(...)` call
4. Migrate all call sites from `SquareEyesView` → `MascotView` (7 files)
5. Rename `SquareEyesView.swift` → `SquareEyesRenderer.swift`, make internal
6. `MascotMetrics.swift` — kill all magic multipliers
7. `SquareEyesPose.swift` — replace all switch statements
8. Add mouth bezier path with interpolatable `mouthCurve`
9. Replace blink Timer with `KeyframeAnimator`
10. `TimelineView` idle float + iris glow shifts
11. Squash/stretch `triggerReaction()` + wire into DashboardView
12. First seasonal overlay: `WinterOverlayView` (snowflakes + hat)
