# DoomScroll — Claude Code Guidelines

## Testing rule (non-negotiable)

**Any code change that affects business logic MUST include a corresponding test change in the same commit.**

This means:
- New function or method → add test cases covering the happy path and edge cases
- Changed behaviour (bug fix, logic update) → update existing tests to reflect the new expected behaviour; add a regression test that would have caught the bug
- Deleted code → remove the tests that covered it
- New model field or computed property → add Codable round-trip test and value tests

Do not commit logic changes without touching `DoomScrollTests/`. If a change is genuinely untestable (FamilyControls, ManagedSettings, ShieldAction — things that require a physical device and entitlements), say so explicitly and add a case to `TESTING.md` instead.

### Test files and what they cover

| File | Covers |
|---|---|
| `DoomScrollTests/OverrideTrackerTests.swift` | Override counting, daily limit, `attemptOverride`, per-token isolation, streak increment/break/advance |
| `DoomScrollTests/LifetimeImpactCalculatorTests.swift` | Year projection math, daily average, relational stake text, `durationString` |
| `DoomScrollTests/UserProfileTests.swift` | `ageGroup` bucketing, `yearsRemaining`, Codable round-trip, save/load |
| `DoomScrollTests/ShieldConversationStateTests.swift` | Default values, all three steps, per-token isolation, `sessionBudgetSeconds = 900` |
| `DoomScrollTests/ReflectionEngineTests.swift` | All 9 age×gender combos, app name/minute injection, tone checks |

### What cannot be automated (document in TESTING.md instead)

- FamilyControls authorization
- Shield appearing over a shielded app (ManagedSettings)
- ShieldAction conversation flow (requires device + entitlement)
- DeviceActivity threshold events
- Widget on the home screen
- StoreKit sandbox purchases

---

## Project structure

```
DoomScroll/           Main SwiftUI app
  App/                Entry point + AuthorizationManager
  Design/             DesignSystem.swift — all DS.Color, DS.Font, DS.Spacing tokens
  Models/             UserProfile, OverrideTracker, AppBlocker, FocusSession, FocusModeManager
  AI/                 ReflectionEngine (static prompts) + AIReflectionEngine stub (iOS 26)
  Subscriptions/      SubscriptionManager (StoreKit 2) + PaywallView
  Shared/             SharedDefaults — App Group storage shared by all 5 targets
  Views/              All screens + SquareEyesView mascot

ShieldConfigurationExtension/   Shield overlay UI (UIKit, runs in extension process)
ShieldActionExtension/          Shield button handling (state machine)
DeviceActivityMonitorExtension/ Background usage monitor (stub — see TODO #14)
DoomScrollWidget/               Home screen widget (small + medium)
DoomScrollTests/                Unit test suite (XCTest)
```

## Key architectural rules

- **SharedDefaults.store** is `static var` (not `let`) — tests inject a clean `UserDefaults(suiteName:)` in `setUp()`. Production code never reassigns it.
- **DS.Color / DS.Font / DS.Spacing** — always use design system tokens; never hardcode hex values or raw sizes in views.
- **UIColor extensions** live in `DesignSystem.swift` alongside SwiftUI Colors — required because shield extensions run in UIKit processes.
- **App Group suite name** is `"group.com.doomscroll"` — used by all 5 targets.
- **FamilyControls authorization** must never be gated behind a subscription (App Store guideline 3.1.3).
- **`OverrideTracker.attemptOverride`** is the atomic write path at the `.commit` step. `canOverride` is read-only for display. Never bypass `attemptOverride` with a direct `recordOverride` at commit time.

## Branch

Development branch: `claude/brainrott-ios-idea-ncf6K`
