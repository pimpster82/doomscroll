# Rive Mascot — Designer Brief

This document tells you exactly what to build in the Rive editor so that `RiveMascot.swift` can drive the character without any code changes.

---

## File to deliver

`square_eyes.riv` — place in the Xcode project under `DoomScroll/Mascot/Rive/`.  
Add it to the **DoomScroll** target only (not the widget or extension targets).

---

## Artboard

| Property | Value |
|---|---|
| Name | `Mascot` |
| Canvas size | 400 × 400 px (square; the runtime scales to whatever `size` the app requests) |
| Background | Transparent |

---

## State Machine

| Property | Value |
|---|---|
| Name | `MoodMachine` |

### Inputs

| Input name | Type | Purpose |
|---|---|---|
| `Mood` | **Number** | Selects which mood state is active (see values below) |
| `Season` | **Number** | Activates a seasonal layer (0 = none, see table below) |
| `React` | **Trigger** | One-shot: plays a reaction clip, then returns to current mood |

The names are **case-sensitive** and must match exactly. The Swift code references them as string literals.

---

## Mood states

Each state corresponds to one value of the `Mood` number input.  
Create one **Animation State** node per row in the state machine graph.

| State node name | `Mood` value | Character disposition |
|---|---|---|
| `Idle` | 0 | Resting; slow blink, gentle breathing |
| `Happy` | 1 | Positive feedback, streak going well |
| `Proud` | 2 | Achievement milestone; chest out |
| `Concerned` | 3 | Warning / needs attention; furrowed brow |
| `Sleepy` | 4 | Overrides depleted; heavy eyelids |
| `Disappointed` | 5 | Streak broken; drooping posture |
| `Celebrating` | 6 | Major milestone (30-day streak, first session); arms up |

### Transitions

Wire **every** state to every other state with the condition:

```
Mood == <target value>
```

Example: `Idle → Happy` fires when `Mood == 1`.  
Use the **Any State** shortcut in Rive's graph to avoid wiring 42 individual arrows:

1. Add an **Any State** node.
2. From **Any State** draw one transition per mood state.
3. Set each transition's condition to `Mood == N` for the appropriate N.

**Transition blend time:** 0.2 s (feel free to adjust per state — `Celebrating` may warrant a longer ease-in).

---

## Seasonal layers

The `Season` number input activates a decorative layer on top of the base character.
Each season is a self-contained layer/group inside the artboard — it doesn't affect the character's shape or animations, it just adds accessories, particles, or colour overlays.

| `Season` value | Theme | Ideas |
|---|---|---|
| 0 | None | Layer hidden |
| 1 | Winter ❄️ | Falling snowflakes, cold-blue tint, Santa hat on head |
| 2 | Halloween 🎃 | Bat particles, pumpkin nearby, orange iris tint |
| 3 | Spring 🌸 | Drifting petals, warm pink blush overlay |
| 4 | World Cup ⚽ | Bouncing football, shorts/kit strip, confetti |

**Implementation approach:**
1. Create one group/layer per season inside the artboard.
2. Add a transition in the state machine: from **Any State**, condition `Season == N` → show the matching group, hide all others.
3. `Season == 0` hides every seasonal group.
4. The user can disable seasonal layers from the app Settings ("Seasonal Fits" toggle) — Swift will send `Season = 0` when the toggle is off, regardless of the current date.

**Additive rule:** Seasonal layers must not reposition, resize, or recolour anything that belongs to the base character. They are always additive — they sit on top and can be removed cleanly.

---

## React trigger

The `React` input is a one-shot **Trigger**.  

Recommended implementation:

1. Create a short loopless animation (0.4–0.8 s) called `ReactClip` — a bounce, a shimmy, a flash of stars, anything energetic.
2. Add an **Animation State** node called `Reacting` that plays `ReactClip` once (Loop: **One Shot**).
3. From **Any State** draw a transition to `Reacting` with condition: `React` (trigger is active).
4. From `Reacting` draw a transition back to **Any State** (or to `Idle` specifically) with no condition — it fires automatically when `ReactClip` ends.

This means whenever `triggerReaction()` is called from Swift, the mascot plays the reaction clip and then returns to whatever mood it was already showing — no extra state bookkeeping needed in code.

---

## WidgetKit / static snapshot

When `animated: false` is passed (WidgetKit, accessibility reduced-motion), the `RiveViewModel` is created with `autoPlay: false` and no inputs are set. The runtime renders the **first frame of the artboard** — make sure that frame looks reasonable (a neutral idle pose works well).

---

## Asset naming checklist for handoff

- [ ] Artboard named exactly `Mascot`
- [ ] State machine named exactly `MoodMachine`
- [ ] Number input named exactly `Mood`
- [ ] Number input named exactly `Season`
- [ ] Trigger input named exactly `React`
- [ ] Seven mood Animation State nodes with names matching the Mood table above
- [ ] Four seasonal layer groups: Winter (1), Halloween (2), Spring (3), WorldCup (4)
- [ ] `Season == 0` hides all seasonal layers
- [ ] First frame of the artboard shows a neutral idle pose with no seasonal layer
- [ ] File exported as `square_eyes.riv`
