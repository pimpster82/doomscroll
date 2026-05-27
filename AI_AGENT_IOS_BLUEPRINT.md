# AI-Assisted iOS App Development Blueprint

A reusable template derived from building DoomScroll — a FamilyControls-based screen time friction app with StoreKit 2 subscriptions, a WidgetKit home screen widget, a custom mascot, and four app extensions.

---

## Phase Structure

The correct sequence is non-negotiable. Each phase produces artifacts that later phases depend on. Skipping or reordering causes rework.

```
Phase 0 — Research fan-out (parallel agents, no code)
Phase 1 — Pre-code resolution (entitlements, privacy, architecture decisions)
Phase 2 — Design system + personality layer (no app code yet)
Phase 3 — Data models + shared layer (pure Swift, no views)
Phase 4 — Main app views (consume design system + models)
Phase 5 — Extensions (shell code that imports shared layer)
Phase 6 — Subscriptions (StoreKit 2, paywall view)
Phase 7 — Widget (reads shared layer, renders design system)
Phase 8 — Mid-build quality gates (security + code correctness audits)
Phase 9 — Additional features (Focus Mode, etc.)
Phase 10 — Final audit gauntlet (hardware, compliance, App Store)
Phase 11 — SETUP.md + TODO.md
```

---

## Phase 0 — Research Fan-Out (Before Any Code)

Spin up parallel agents for every domain where ignorance will cause architectural mistakes. These are not optional. Every issue the DoomScroll audits caught late — `.defer` vs `.close`, FamilyControls entitlement, PrivacyInfo.xcprivacy, the TOCTOU race — would have been caught here.

### Agents to spin up simultaneously

**Agent 1 — Platform constraints**
> "Research iOS [target version] technical constraints for [app category]. Include: which APIs require restricted entitlements and their approval timelines, memory limits for app extensions (particularly ScreenTime extensions), background execution limitations, which APIs are Simulator-incompatible and require a real device, and any APIs that changed behavior between iOS 17 and iOS 18. Return specific limits, not vague descriptions."

**Agent 2 — Behavioral science**
> "Research behavioral science findings relevant to [your app's core mechanic, e.g. 'reducing compulsive app-opening behavior']. Include: what friction patterns work (and at what friction level they stop working), how age and gender affect message framing, what framing causes defensiveness vs. reflection, and what gamification patterns (streaks, progress rings) are supported by retention data. Cite specific studies or products where possible."

**Agent 3 — UI/UX and design patterns**
> "Research iOS UI/UX best practices for [app type]. Specifically: what color systems work for apps that users open daily, what typography hierarchy works best on iOS for [use case], how to design for one-handed use on varying screen sizes (375pt SE through 430pt Pro Max), how Duolingo and other habit apps use mascot characters, and how paywall screens convert. Return concrete patterns, not principles."

**Agent 4 — Monetization + StoreKit**
> "Research iOS subscription pricing and StoreKit 2 implementation. Include: what price points convert for [category] apps (individual monthly, individual annual, family plans), what App Store guidelines say about free trials and auto-renewal disclosures (exact required language), what StoreKit 2 patterns are required vs. optional, how Family Sharing works for subscriptions, and how to test subscriptions without real money. Return the exact disclosure text Apple requires."

**Agent 5 — App Store compliance**
> "Research App Store review guidelines that apply to [app type]. Specifically: what required reason APIs trigger a PrivacyInfo.xcprivacy requirement and what reason codes to use, what privacy-related Info.plist keys are required vs. optional, what metadata requirements exist for apps that collect personal data (age, gender), and what guideline violations are most common for [category] apps. Return the specific guideline numbers."

**Agent 6 — Security model**
> "Research security best practices for iOS apps that: use App Groups to share data between a main app and four extensions, store user behavioral data (override logs, usage stats), use UserDefaults for cross-extension communication, and implement a bypass limit that motivated users might try to circumvent. Return specific attack vectors and recommended mitigations."

### Do not write any code until all six agents have reported back.

---

## Phase 1 — Pre-Code Resolution Checklist

Before touching Xcode, resolve every item on this list. Discovering these after building is expensive.

### Entitlements and Apple portals (do these on day 1 — some have multi-day wait times)

- [ ] **FamilyControls entitlement** (if using ScreenTime APIs): Submit the form at `developer.apple.com/contact/request/family-controls-distribution`. Wait time: 1–5 business days. You cannot test on a real device without approval.
- [ ] **App Group identifier** registered in Apple Developer portal. Decide your group name now (`group.com.yourapp`) — it will be hardcoded in every extension entitlement and cannot easily change later.
- [ ] **All bundle IDs registered**: main app, plus one per extension (Shield, ShieldAction, DeviceActivityMonitor, Widget, etc.). Do this before generating your project.
- [ ] **Team ID** obtained from developer.apple.com → Account → Membership.

### Architecture decisions that must happen before coding

- [ ] **Shared model layer strategy**: Which Swift files will be compiled into both the main app and extensions? Decide now. In DoomScroll: `SharedDefaults.swift`, `DesignSystem.swift`, `SquareEyesView.swift`, `UserProfile.swift`, `OverrideTracker.swift` are all compiled into the widget. Extensions that use UIKit (ShieldConfigurationExtension) cannot use SwiftUI. Plan your type boundaries.
- [ ] **Extension API behavior**: For every extension type you're building, read the actual API docs before designing your state machine. For `ShieldActionExtension`: `.defer` re-renders the current shield, `.close` dismisses it, `.none` allows the app to open. Getting this wrong (using `.defer` when you mean `.close`) creates a flicker loop that requires an architectural fix, not a patch.
- [ ] **Cross-extension communication**: App Groups via `UserDefaults(suiteName:)` — but the suite name init returns an optional. Do not force-unwrap it. Decide your fallback behavior now.
- [ ] **PrivacyInfo.xcprivacy**: Required since Spring 2024. List every "required reason API" you will use: `UserDefaults` → reason `CA92.1`, `Date()`/file timestamps → reason `35F9.1`. Create the file before submission.
- [ ] **Deployment target**: Set once. It determines which APIs you can use without availability checks. For Screen Time APIs: iOS 16+. For the latest WidgetKit container APIs: iOS 17+.
- [ ] **Subscription model**: Decide your product IDs now (`com.yourapp.individual.monthly`, etc.) and create them in App Store Connect. They must exist before StoreKit 2 can load them.

---

## Phase 2 — Design System + Personality Layer

**No app views until this phase is complete.** Every view that gets written before the design system exists will be rewritten. DoomScroll required a full coherent design pass as its third major artifact — avoidable.

### Design system prompt

> "Create a complete Swift design system for [app name] as a single `DesignSystem.swift` file. The app's emotional character is [describe: e.g. 'warm, non-judgmental, encouraging — the opposite of the anxiety-inducing apps it fights']. Include:
> 1. A color palette with semantic names (background, backgroundCard, backgroundMuted, textPrimary, textSecondary, textTertiary, accent, accentMuted, success, successMuted, warning, warningMuted) — use warm, named values that reflect the emotional character
> 2. For every SwiftUI Color, also provide a UIColor extension with the same value — required because extensions use UIKit, not SwiftUI
> 3. An SF Pro typography scale with at least: hero (56pt bold rounded), title (28pt bold rounded), title2, headline, body, callout, caption, label
> 4. A spacing scale (xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48)
> 5. Corner radius tokens (sm, md, lg, full)
> 6. A reusable DSCard view container
> 7. A SectionLabel component
> Do NOT use fixed hex colors that ignore system dark mode without explicitly calling this out. If the app forces light mode, add .preferredColorScheme(.light) to the window group and document why. If the app supports dark mode, use Color(uiColor: UIColor { traits in ... }) adaptive colors from the start."

**Critical**: Define UIColor variants alongside SwiftUI Colors in the same file. Extensions like ShieldConfigurationExtension and ShieldActionExtension run in UIKit processes and cannot use SwiftUI Color. If you define only SwiftUI colors, you will rewrite the design system when you build the first extension.

### Mascot and personality prompt

Run this before building any UI, including the mascot view.

> "Design the character personality and visual specification for [app name]'s mascot. Define:
> 1. Character concept (1–2 sentences): what it is, what it represents, why users would feel affection for it
> 2. Emotional states it must express: idle, happy, concerned, sleepy, proud, disappointed — and what each state means in context
> 3. Visual design: body shape, colors (map to the existing design system palette), distinctive features, animation behaviors (breathing, blinking)
> 4. Voice/tone: 3–5 example phrases the mascot would say in different situations. These should feel like a consistent personality, not generic app copy.
> 5. Where the mascot appears: onboarding, dashboard, paywall, widget — and what state it shows in each context
> The mascot must be implementable as a SwiftUI view using only primitives (no image assets), so it renders in the widget and all extensions."

Do not build the mascot view until this spec exists. The spec becomes the docstring at the top of the mascot view file.

---

## Phase 3 — Data Models + Shared Layer

Build pure Swift types before any views. These have no UI dependencies and establish the data contracts every layer will use.

**Build order within this phase:**
1. Shared constants (`SharedDefaults.swift`) — App Group suite name, all keys, `updateWidgetSnapshot()`. All other files depend on this.
2. User profile models (`UserProfile.swift`, `UserProfile+Storage.swift`)
3. Core tracking models (`OverrideTracker.swift`, session models)
4. Calculation/business logic (`LifetimeImpactCalculator.swift`, `ReflectionEngine.swift`)
5. Manager classes (`AppBlocker.swift`, feature managers) — these depend on models

**Key pattern prompt:**
> "Write [ModelName].swift for [app name]. Requirements:
> - Pure Swift, no UIKit or SwiftUI imports unless essential
> - All persistence goes through SharedDefaults (already defined, use the existing suiteName)
> - No force-unwraps on optional values from UserDefaults
> - Use static let for the shared UserDefaults instance, not a computed property (avoids allocating a new object on every access)
> - Any function that both reads and writes state (like 'check if can override, then record override') must be a single atomic function to prevent TOCTOU races
> - Codable conformance where the type needs to cross process boundaries"

---

## Phase 4 — Main App Views

Now build views, consuming the design system and models from Phases 2–3.

**Build order:**
1. `DoomScrollApp.swift` — entry point, environment object setup
2. `AuthorizationView.swift` — first screen, no dependencies
3. `OnboardingView.swift` — depends on profile models and app picker
4. `DashboardView.swift` — main experience, depends on everything
5. Feature views (`FocusModeView.swift`, `SettingsView.swift`, `ActiveFocusView.swift`)
6. `SquareEyesView.swift` — the mascot view, implement per the spec from Phase 2

**Critical @StateObject rule**: `@StateObject` is for objects the view creates and owns. `@ObservedObject` is for objects that exist elsewhere (singletons). `SubscriptionManager.shared` in a non-root view must use `@ObservedObject`, not `@StateObject`.

---

## Phase 5 — Extensions

Extensions are the highest-risk phase for architectural mistakes because their APIs are poorly documented and behave differently from the main app.

**Build order:** ShieldConfiguration → ShieldAction → DeviceActivityMonitor → (Widget in Phase 7)

**ShieldAction state machine prompt:**
> "Implement ShieldActionExtension for [app name]. The extension handles taps on shield overlay buttons. Constraints:
> - `.defer` re-renders the current shield configuration (use for multi-step flows)
> - `.close` dismisses the shield and keeps the app blocked
> - `.none` (NOT `.allow`, which doesn't exist) allows the app to open
> - The extension cannot open the main app — all conversation must happen here via state cycling
> - State must be persisted to App Group UserDefaults between calls (the extension is re-instantiated on every button tap)
> - The override limit check and override record must be a single atomic operation — not a canOverride() call followed by a separate recordOverride() call
> - Session budget seconds must be written to state before the commit step fires — not assumed to exist"

**Extension memory limits**: App extensions have a 120MB memory limit (ShieldConfiguration gets ~30MB). Do not load large assets in extensions. The mascot view using pure SwiftUI primitives (no images) is the correct pattern for extensions.

---

## Phase 6 — Subscriptions

**Required App Store disclosure text** (exact wording Apple requires — do not paraphrase):

> "Payment will be charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings. Any unused portion of a free trial is forfeited on purchase."

**Subscription implementation prompt:**
> "Implement StoreKit 2 subscription management for [app name]. Requirements:
> - Product IDs: [list them] — these must match App Store Connect exactly
> - Listen for transaction updates from app launch (not just after purchase)
> - `refreshEntitlements` must guard against calling before `loadProducts` completes, otherwise `products.first { $0.id }` returns nil and the user appears unsubscribed
> - Check `product.subscription?.introductoryOffer` eligibility before showing 'free trial' CTA — users who previously cancelled are not eligible for a second trial
> - If subscription lapses, remove all active shields (`AppBlocker.removeAll()`) — do not leave restrictions in place for a lapsed account
> - Do NOT gate `FamilyControls` authorization behind subscription — App Store guideline 3.1.3 prohibits this
> - Include the exact App Store required disclosure text in the paywall footer"

---

## Phase 7 — Widget

**Widget constraints**:
- No network calls in `getTimeline`
- No `UserDefaults(suiteName:)` init failures silently (App Group must be configured)
- `animated: false` must be passed to any animated view (the mascot) — WidgetKit renders a static snapshot
- Widget reads from App Group. Main app must call `WidgetCenter.shared.reloadAllTimelines()` whenever the underlying data changes, or data will be stale

**Widget prompt:**
> "Implement a WidgetKit widget for [app name] targeting small and medium sizes. The widget reads from App Group ([your suite name]) keys: [list your keys]. It uses [MascotView] with `animated: false`. The timeline refreshes every 15 minutes. The provider must not make network calls or read from disk beyond the shared UserDefaults. Include a static preview entry so Xcode Previews work without App Group access."

---

## Phase 8 — Mid-Build Quality Gates

Run these audits after extensions and subscriptions are built but before shipping or adding features. Do not wait until the end.

**Security audit prompt:**
> "Audit this iOS app's security model. Code is in [paste relevant files]. Specifically look for: force-unwraps on shared storage that would crash silently in extensions, unencrypted storage of sensitive data in App Group UserDefaults (which is readable by any process in the group and by iTunes backups), TOCTOU race conditions where a check and a write are separate operations, bypass attacks on rate-limit controls (are limits stored where a user could delete them?), and any places where state is assumed to exist that may not."

**Code correctness audit prompt:**
> "Review this Swift code for correctness issues. Files: [paste]. Look for: @StateObject used with pre-existing singletons (should be @ObservedObject), Timer instances that fire after the view disappears (timer orphans), async functions that don't guard against race conditions during product loading, hardcoded values that should come from real data, and calendar/date arithmetic errors (e.g., using year component subtraction instead of date components for age)."

---

## Phase 10 — Final Audit Gauntlet

Run all four audits simultaneously before App Store submission.

**Hardware/compatibility audit:**
> "Audit this iOS app for hardware compatibility issues. Look for: architectures listed in Info.plist that do not match the deployment target (armv7 is invalid for iOS 18+), layout issues on the smallest supported screen (375pt wide for iPhone SE), layout issues on the largest screen (430pt for iPhone Pro Max), API calls that return different results on different chip generations, and any feature that requires specific hardware not universally available."

**App Store compliance audit:**
> "Audit this iOS app against App Store Review Guidelines. Check: subscription paywall has the exact required auto-renewal disclosure text, free trial eligibility is checked before showing the trial CTA, any API that requires a restricted entitlement is declared correctly and used in a way consistent with the entitlement's stated purpose, PrivacyInfo.xcprivacy lists all required reason APIs with valid reason codes, the app does not gate required FamilyControls authorization behind a paywall, privacy policy URL is present in Info.plist if personal data is collected."

---

## iOS-Specific Traps Checklist

Check every one of these at project start, not after building:

- **FamilyControls entitlement**: 1–5 day approval wait from Apple. Submit the form on day 1.
- **PrivacyInfo.xcprivacy**: Required for all apps using `UserDefaults` (CA92.1), `Date()` (35F9.1), or file system timestamps. Missing = automatic App Store rejection.
- **Extension memory limits**: ShieldConfigurationExtension ~30MB, app extensions generally 120MB. No large images in extension targets.
- **App Group consistency**: Every target that shares data must declare the same App Group in its entitlements. One missing target = silent runtime failure, not a build error.
- **`.defer` vs `.close` vs `.none`** in ShieldActionExtension: `.defer` re-renders the current shield (multi-step flow), `.close` keeps blocked, `.none` allows open. These are not interchangeable.
- **`@StateObject` vs `@ObservedObject`**: `@StateObject` creates and owns. `@ObservedObject` observes something that exists elsewhere. Using `@StateObject` with a singleton is semantically wrong.
- **UserDefaults force-unwrap**: `UserDefaults(suiteName:)` returns an optional. Force-unwrapping crashes all extension processes silently if the App Group entitlement is misconfigured. Use a guarded init with an `assertionFailure` fallback.
- **Dark mode**: Fixed hex colors in a design system will break in system dark mode. Either use adaptive `UIColor` trait-collection closures from day one, or force light mode with `.preferredColorScheme(.light)` intentionally documented.
- **`armv7` in Info.plist**: iOS 18 runs on arm64 only. Remove or replace any boilerplate `armv7` architecture declaration.
- **Session budget write**: Any value read at step N of a multi-step flow must be written at step N-1. Reading `sessionBudgetSeconds` at the commit step without writing it at the reflection step = always zero.
- **Atomic check-and-write**: Any pattern that reads state, checks a condition, then writes state in two separate calls is a TOCTOU race. Combine into one function.
- **Widget animated views**: Pass `animated: false` to any view that uses Timers or animations — WidgetKit renders a snapshot, Timers do not fire.
- **StoreKit product race**: `refreshEntitlements` can fire (from `Transaction.updates`) before `loadProducts` completes. Guard with `if products.isEmpty { await loadProducts() }` before looking up a product by ID.
- **Subscription lapse cleanup**: When `activeSubscription` becomes nil, remove all active restrictions. Don't leave a paying-only feature active for a lapsed account.
- **Paywall trial eligibility**: Check `product.subscription?.introductoryOffer` before showing "Start free trial" — previously cancelled users are not eligible for a second trial. Showing the CTA anyway is misleading.

---

## Design System Principles

**Why design tokens must exist before any view code:**

Every view references colors, fonts, spacing, and radii. If these are defined inline at the view level, a later "make this consistent" pass touches every file. If they live in `DesignSystem.swift`, consistency is automatic and the design system becomes the only file to update when the palette changes.

**The UIColor requirement for extensions:**

ShieldConfigurationExtension and ShieldActionExtension run in UIKit processes. `SwiftUI.Color` does not exist in these processes. You must provide `UIColor` equivalents for every semantic color used in extensions. Define them in the same `DesignSystem.swift` file as `extension UIColor` static properties. If you define only SwiftUI Colors and then build your first extension, you will rewrite the design system.

**What the design system file must contain:**

```
enum DS {
    enum Color { ... }   // SwiftUI Color statics
    enum Font { ... }    // SwiftUI Font statics
    enum Spacing { ... } // CGFloat statics
    enum Radius { ... }  // CGFloat statics
}
extension UIColor {
    // Mirror of DS.Color as UIColor statics
}
// Reusable container views (DSCard, SectionLabel)
```

**Dark mode from day one:**

If your app must support dark mode, use `Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? darkColor : lightColor })` for every semantic color. Retrofitting adaptive colors after building 10 views requires touching every file. If intentionally forcing light mode, add `.preferredColorScheme(.light)` to the root `WindowGroup` and document the design rationale — warm-background wellness apps often legitimately prefer light mode.

---

## The Mascot/Personality Layer

**Define before building any UI, including the mascot view itself.**

The mascot is not decoration. It is the emotional interface between the app's logic and the user's state. In DoomScroll, Square Eyes expresses concern during onboarding (foreshadowing), pride after streak milestones, sleepiness when overrides are exhausted. These states must be designed together with the UX flow — you cannot design them after the fact.

**What the personality spec must include:**

1. The character concept in one sentence (what it is, what it knows, why it cares)
2. Every emotional state with a screen-context description (not just "happy" — "happy when streak > 3 days or reclaimed > 70%")
3. Voice guide: 5 example phrases showing consistent tone. This prevents view copy from sounding like a different character in each screen.
4. Where it appears and at what size (widget at 70pt needs simpler geometry than onboarding at 110pt)
5. Animation constraints: breathing (always), blinking (only when `animated: true`), expression transitions (spring animation)

**Implementation rule:** The mascot view must work with `animated: false` for WidgetKit. Use a parameter to gate all Timer-based animation (`var animated: Bool = true`). Widget passes `false`. The idle breathing animation and blink timer must not start when `animated` is false — Timers do not fire in WidgetKit snapshots.

---

## Prompt Patterns That Work

**Research-first prompts** (Phase 0 agents): Ask for specific findings with specific outputs. "What does the API do?" with a one-word answer is useless. "What are the exact values returned by ShieldActionResponse and what does each value cause the system to do?" is actionable.

**Scope-bounded build prompts**: Give every build prompt a file scope. "Implement OverrideTracker.swift. It must: [requirements list]. It must not import SwiftUI. It reads/writes through SharedDefaults (already defined). Return only the file contents." Unbounded prompts produce code that touches files you didn't intend to change.

**Constraint-enumerated prompts**: List every constraint explicitly. "No force-unwraps. Atomic check-and-write. Static let for UserDefaults instance." Don't assume the agent knows iOS best practices — enumerate the ones that matter for your context.

**Parallel audit prompts**: Run security, code correctness, hardware, and compliance audits simultaneously. Each has a distinct lens and they don't interfere with each other. Running them in sequence is wasteful.

**What to avoid:**

- "Make this better" — no bounded output, no success criterion
- Building views before the design system — guarantees a rewrite pass
- Building extensions before reading the API docs for that extension type — the API surface area is small but the behavior is non-obvious
- Single-pass audits at the end — architectural bugs (`.defer` vs `.close`) are expensive to fix after the state machine is built around them
- Asking one agent to simultaneously research and build — the research phase often changes what gets built, so separating them prevents throwing away code

---

## Example Agent Prompts by Phase

**Phase 0 — iOS constraints agent:**
> "I am building an iOS 18 app that uses FamilyControls, ManagedSettings, ShieldConfigurationExtension, ShieldActionExtension, DeviceActivityMonitor, WidgetKit, and StoreKit 2. Before I write any code, tell me: (1) which of these APIs require a restricted entitlement and what the request process is, (2) whether any of these APIs work in the Simulator or require a physical device, (3) what the memory limits are for each extension type, (4) what ShieldActionResponse values exist and exactly what each one does to the UI, (5) what PrivacyInfo.xcprivacy entries are required given this API list."

**Phase 2 — Design system:**
> "Create DesignSystem.swift for an iOS app called [name] whose emotional character is [describe]. The app has a main SwiftUI target and four extensions: two Shield extensions (UIKit processes), a DeviceActivityMonitor extension, and a WidgetKit widget. Every SwiftUI Color must have a matching UIColor extension property. The app intentionally forces light mode because [reason] — document this in a comment. Include DSCard and SectionLabel components."

**Phase 3 — Shared layer:**
> "Create SharedDefaults.swift for [app name]. App Group suite name is [group.com.yourapp]. Define all keys as string constants in a nested Key enum. The store property must be a static let (not computed var) initialized with a guarded init that falls back to .standard with an assertionFailure if the App Group is misconfigured. Include a updateWidgetSnapshot(streak:reclaimedPercent:overridesLeft:) function that writes to the store and calls WidgetCenter.shared.reloadAllTimelines() wrapped in a canImport(WidgetKit) check."

**Phase 5 — ShieldAction extension:**
> "Implement ShieldActionExtension.swift for [app]. The flow is: impact → reflection → commit. At the commit step, call completionHandler(.none) — NOT .allow, which does not exist. At any step where the user taps secondary, call completionHandler(.close) — NOT .defer. When overrides are exhausted, call .close, not .defer. State is persisted in ShieldConversationState via App Group UserDefaults between button taps. sessionBudgetSeconds must be set to 900 when advancing from reflection to commit — read it at the commit step from state, not from a hardcoded value."

**Phase 8 — Code correctness audit:**
> "Audit the following Swift files for code correctness issues. For each issue found, give: the file name, the line number or function name, the specific problem, and a concrete fix. Look for: @StateObject with a pre-existing singleton (should be @ObservedObject), Timer or DispatchQueue.asyncAfter callbacks that execute after the view disappears, state values that are read but never written, async functions that can fire before their dependencies are ready, and calendar date arithmetic that is off by up to 1 year. Files: [paste]"

---

*Use this blueprint as a pre-flight checklist for every new iOS app project. The research phase and pre-code resolution checklist are the highest-leverage parts — they prevent the categories of mistakes that are most expensive to fix after code exists.*
