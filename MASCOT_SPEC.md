# Square Eyes — Mascot Redesign Spec

## What's wrong with the current implementation

The current SquareEyes is a flat, lifeless assemblage of rectangles. The specific problems:

- **No depth.** Uniform mint fill, no shadow, no gradient, no inner glow. Looks like a CSS mockup.
- **Eyes only.** Expressions rely entirely on eye scale/offset. No mouth, no body language, no weight.
- **No squash/stretch.** The body never deforms. Every transition is a uniform linear scale.
- **No follow-through.** Arms snap to position. Nothing settles, overshoots, or jiggles.
- **Fragile animation.** Timer + DispatchQueue.asyncAfter for blinking is unpredictable, doesn't pause when app backgrounds, and fights with expression transitions.
- **Tightly coupled.** Adding a new expression requires editing 5+ switch statements. Swapping the art style is a full rewrite.
- **Magic multipliers everywhere.** `size * 0.28`, `size * 0.59`, `size * 0.23` — no semantic structure, no design tokens.

---

## Character brief

**Square Eyes** is the app's emotional core. A pale mint blob whose eyes are literal TV screens — glowing blue, square-bezelled, slightly wrong. They've been staring at screens their whole life and feel the cost of it. But they're not sad: they want to help.

They should feel:
- **Slightly weary** at rest (not depressed — just a creature that has seen too many feeds)
- **Genuinely warm** when celebrating (not performed joy — real relief)
- **Gently alert** when concerned (not panicked — just noticed something)
- **Irresistibly sleepy** when depleted (heavy eyelids, drooping head)

They should look like they have **weight**, **breath**, and **intention**.

---

## Technical architecture

### Protocol boundary (non-negotiable)

All call sites use this interface and nothing else:

```swift
// Public API — must remain stable forever.
// Internal rendering can be replaced entirely without touching callers.
struct SquareEyesView: View {
    var expression: SquareEyesExpression = .idle
    var size: CGFloat = 120
    var animated: Bool = true   // false for WidgetKit snapshots
}

enum SquareEyesExpression: String, Equatable, CaseIterable {
    case idle, happy, concerned, sleepy, proud, disappointed
}
```

### Internal architecture

Separate **what the character communicates** from **how it is drawn**:

```
SquareEyesView (public shell)
  └── SquareEyesPose (value type: all geometric state for a given expression)
        ├── bodyScaleX, bodyScaleY       (squash/stretch)
        ├── eyeOpenness                  (0 = closed, 1 = fully open)
        ├── eyeScaleY                    (lids)
        ├── irisScale, irisOffset        (gaze)
        ├── mouthCurve                   (−1 frown → 0 neutral → +1 smile)
        ├── cheekOpacity
        ├── eyebrowOffset, eyebrowTilt
        └── armsRaised: Bool
```

`SquareEyesPose` is a static function of `SquareEyesExpression`. The renderer interpolates between poses using `KeyframeAnimator` or `PhaseAnimator`. The renderer never reads expression directly — it reads pose.

### Geometry: `MascotMetrics` struct

Replace all magic multipliers with one struct:

```swift
struct MascotMetrics {
    let size: CGFloat

    var height:      CGFloat { size * 1.2 }
    var bodyRadius:  CGFloat { size * 0.22 }
    var eyeSize:     CGFloat { size * 0.28 }
    var eyeGap:      CGFloat { size * 0.06 }
    var irisSize:    CGFloat { eyeSize * 0.60 }
    var eyeRadius:   CGFloat { eyeSize * 0.22 }
    var footWidth:   CGFloat { size * 0.18 }
    var footHeight:  CGFloat { size * 0.09 }
    var footGap:     CGFloat { size * 0.12 }
    var footOffsetY: CGFloat { height * 0.44 }
    var armWidth:    CGFloat { size * 0.09 }
    var armHeight:   CGFloat { size * 0.24 }
    var cheekRadius: CGFloat { size * 0.14 }
    var cheekOffX:   CGFloat { size * 0.32 }
    var mouthWidth:  CGFloat { size * 0.34 }
    var mouthHeight: CGFloat { size * 0.12 }
    var eyeOffsetY:  CGFloat { -size * 0.05 }
}
```

---

## Expressions — full spec

### idle
- Eyes: 60% open, iris centered, normal size
- Body: no deformation
- Mouth: very slight downward curve (−0.15) — not sad, just resting
- No cheeks, no arms, no eyebrows
- *Feeling: a creature that is tired but still here*

### happy
- Eyes: arc iris (upward curve, like a ˆ glyph), full eye height
- Body: very slight squash (scaleY 0.96, scaleX 1.03) — small joyful settle
- Mouth: gentle smile (0.6)
- Cheeks: visible (opacity 0.5)
- Arms: raised at ~25° outward
- *Feeling: quiet celebration, not a fist-pump*

### concerned
- Eyes: fully open (scaleY 1.0), iris shifted up 15%, slightly larger iris (1.05×)
- Body: very slight vertical stretch (scaleY 1.02)
- Mouth: flat with corners very slightly down (−0.2)
- Eyebrows: visible, tilted inward (−10° left, +10° right), offset upward
- *Feeling: noticed something, paying attention*

### sleepy
- Eyes: 18% open — heavy drooping lids, iris barely visible (scale 0.3)
- Body: head-droop implied by slight downward offset (+4pt)
- Mouth: slightly open-neutral (0.1 curve, slightly parted)
- No cheeks, no arms
- *Feeling: gravity is winning*

### proud
- Eyes: arc iris (brighter version), full height, iris glow more saturated
- Body: slight upward stretch (scaleY 1.04, scaleX 0.97) — standing taller
- Mouth: full warm smile (0.85)
- Cheeks: visible (opacity 0.65)
- Arms: raised higher than happy (~35°), slight outward lean
- *Feeling: actually did the thing*

### disappointed
- Eyes: 45% open, iris shifted down 12%, iris slightly smaller (0.8×)
- Body: slight slump (scaleY 0.97)
- Mouth: soft downward curve (−0.5)
- Eyebrows: slight inward droop (subtle)
- *Feeling: was hoping for better*

---

## Animation system

### Blink — KeyframeAnimator (replaces Timer + asyncAfter)

Blink on a random cadence using a `@State var blinkTrigger: Int` incremented by a background Timer. Occasionally double-blink (10% chance).

```
Keyframe sequence for single blink (total 0.18s):
  0.00s: scaleY = 1.0
  0.07s: scaleY = 0.04   (fast close)
  0.13s: scaleY = 0.04   (hold closed)
  0.18s: scaleY = 1.0    (slightly slower open)

Double blink adds a second close/open at 0.28–0.42s.
```

### Expression transition — KeyframeAnimator

When `expression` changes, animate all pose fields with coordinated but not identical timing. Body deformation leads, eyes follow 40ms later, mouth follows 80ms later (secondary action).

```
Body scale change:  SpringKeyframe, stiffness: 280, damping: 22
Eye lid change:     SpringKeyframe, stiffness: 350, damping: 28  (eyes are snappy)
Iris offset:        SpringKeyframe, stiffness: 200, damping: 20  (iris floats)
Mouth curve:        CubicKeyframe, duration: 0.25s              (mouth melts)
Arm raise:          SpringKeyframe(bounce: 0.45)                (arms have spring)
```

### Idle float — TimelineView + sinusoidal offset

```swift
TimelineView(.animation) { timeline in
    let t = timeline.date.timeIntervalSinceReferenceDate
    let y = sin(t * 0.8) * 3.5   // primary float: ±3.5pt, 7.9s period
    let rot = sin(t * 0.5) * 1.2 // subtle tilt: ±1.2°, 12.6s period
    // Two different frequencies → Lissajous pattern, never exactly repeats
}
```

### Reaction squash/stretch (for significant events)

Triggered externally when override attempt or session ends:

```
Phase 1 (impact):     scaleX 1.22, scaleY 0.78  — 0.08s, easeOut
Phase 2 (overshoot):  scaleX 0.93, scaleY 1.08  — 0.18s, spring bounce:0.5
Phase 3 (settle):     scaleX 1.00, scaleY 1.00  — 0.25s, spring
```

Expose as: `squareEyesView.triggerReaction()` — a method or a `@Binding<Bool>` that fires the sequence.

### Iris glow — mood-responsive

The iris drop shadow shifts with expression:
- idle: `shadow(color: .blue.opacity(0.3), radius: 4)`
- concerned: `shadow(color: .orange.opacity(0.5), radius: 7)` — warm amber shift
- proud/happy: `shadow(color: .blue.opacity(0.7), radius: 8)` — bright saturated
- sleepy: `shadow(color: .blue.opacity(0.1), radius: 2)` — barely visible

### Mouth shape — Path-based

Draw mouth as a cubic bezier with two control points:
- Neutral (curve 0): horizontal line, control points on center Y
- Smile (curve +1): control points lifted → upward arc
- Frown (curve −1): control points dropped → downward arc

Intermediate values interpolate smoothly. Animate `mouthCurve` through `animatableData` or `KeyframeAnimator`.

---

## Depth improvements

These are small code changes with large visual impact:

1. **Body inner shadow** — A slightly darker version of `mascotBody` as an inner stroke overlay (`Capsule().stroke(Color(hex:"C8E4DC"), lineWidth: 2).blur(radius: 1)`) creates soft dimensionality.

2. **Eye frame depth** — The TV-screen bezel gets a 1pt bottom edge highlight (`Color.white.opacity(0.12)`) to imply a beveled screen edge.

3. **Iris glow** — Already specified above. This is the highest-ROI single change.

4. **Foot shadow** — A small blurred ellipse below each foot (opacity 0.12, blur 3) grounds the character.

5. **Body color variation** — The body could have a very subtle radial gradient from `#EEF7F3` (center highlight) to `#D8EDE6` (edge shadow) to suggest roundness without a texture asset.

---

## What cannot be unit-tested

- Blink timing and visual rhythm (must be reviewed on device)
- Squash/stretch feel (must be reviewed at 60 FPS)
- Mouth curve shape at intermediate expression values
- Idle float naturalness

Add manual test cases to TESTING.md for each.

---

## Implementation order (recommended)

1. `MascotMetrics` struct — zero visual change, eliminates magic numbers
2. `SquareEyesPose` value type + static pose lookup — decouples expression from renderer
3. Mouth bezier path + `mouthCurve` interpolation — highest expressiveness gain
4. Replace blink Timer with `KeyframeAnimator` — reliability fix
5. `TimelineView` idle float + subtle rotation — aliveness
6. Iris glow shift by expression — depth + emotion tie-in
7. Squash/stretch on expression transitions — Disney principle #1
8. Reaction trigger method + `triggerReaction()` call sites in DashboardView
9. Body depth cues (inner shadow, foot shadow, radial gradient)
10. Eye-tracking toward nearest interactive element (optional stretch)

---

## Call sites to update after redesign

| File | Size | Notes |
|---|---|---|
| `DashboardView.swift` | 64pt | Wire `triggerReaction()` on override attempt result |
| `FocusModeView.swift` | 64pt | — |
| `ActiveFocusView.swift` | 72pt + 52pt | 52pt hardcoded `.concerned` could use `.disappointed` |
| `OnboardingView.swift` | 110pt + 56pt | Welcome `.concerned` could transition to `.happy` after step 1 |
| `AuthorizationView.swift` | 120pt | Hardcoded `.concerned` — correct |
| `PaywallView.swift` | 100pt | Dynamic expression on tier change — correct |
| `DoomScrollWidget.swift` | 70pt + 80pt | `animated: false` — only pose rendering matters here |
