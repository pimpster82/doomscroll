# DoomScroll — Open Tasks

Findings from security, hardware, code correctness, and App Store compliance audits,
plus known feature gaps. Ordered by priority within each section.

Legend: ✅ Done · 🔧 Manual action required · ⬜ Open

---

## 🔴 CRITICAL — Fix before any device testing

### ✅ 1. Set sessionBudgetSeconds before committing an override
Fixed in commit `d2f1947` — `state.sessionBudgetSeconds = 900` set in the `.reflection` case.

### ✅ 2. Fix wrong `.defer` response when overrides are exhausted
Fixed in commit `d2f1947` — changed `completionHandler(.defer)` → `completionHandler(.close)`.

### 🔧 3. Apply for the FamilyControls entitlement from Apple
**Portal action — takes 1–5 business days. Do first.**
Without this, the binary is rejected before a human reviewer sees it.

1. Go to https://developer.apple.com/contact/request/family-controls-distribution
2. Fill in: App name = **DoomScroll**, Bundle ID = `com.doomscroll.app`
3. Use case: *"Screen time friction app for individuals. Uses FamilyControls to shield selected apps and require a reflection conversation before the user can open them. Individual use only — no parental control of other devices."*

> Code part (AuthorizationView error feedback) is done — commit `f296a83`.

---

## 🟠 HIGH — Fix before App Store submission

### ✅ 4. Fix dark mode
Fixed in commit `f296a83` — `.preferredColorScheme(.light)` added to `WindowGroup`.

### ✅ 5. Add required auto-renewal disclosure to PaywallView
Fixed in commit `f296a83` — full Apple-required disclosure text with dynamic price from `selectedProduct.displayPrice`.

### ⬜ 6. Add a privacy policy and `NSPrivacyPolicyURL`
**Depends on manual step (6a) before the code can be completed.**

**6a — 🔧 Write and host the privacy policy (manual)**
Write a plain-language policy covering: birth year (age range), gender, screen-time data — all on-device only, never transmitted, no third parties. Host at a stable URL (GitHub Pages is free and permanent):
1. Create a public GitHub repo or use this one's GitHub Pages
2. Add a `privacy-policy.md` (convert to HTML for the URL)
3. The URL format will be: `https://pimpster82.github.io/doomscroll/privacy-policy`

**6b — ✅ Wire the URL into the app**
Added `NSPrivacyPolicyURL` to `DoomScroll/Info.plist` and a tappable `Link("Privacy Policy", ...)` in `SettingsView.aboutSection`. Both point to `https://pimpster82.github.io/doomscroll/privacy-policy`. Complete manual step 6a to host the policy at that URL.

---

### ✅ 7. Create `PrivacyInfo.xcprivacy` manifest
Done in commit `645b74b` — file at `DoomScroll/PrivacyInfo.xcprivacy`. Declares UserDefaults (CA92.1), birth year, and gender. project.yml updated with `buildPhase: resources`.

### ✅ 8. Fix SquareEyesView blink timer orphan
Fixed in commit `f296a83` — `isVisible` flag guards all timer callbacks.

### ✅ 9. Change `@StateObject` to `@ObservedObject` for singletons
Fixed in commit `f296a83` — `PaywallView` changed to `@ObservedObject`.

### ✅ 10. Fix OverrideTracker TOCTOU race condition
Fixed in commit `f296a83` — `attemptOverride()` atomic function; ShieldActionExtension uses it at the `.commit` step.

### ✅ 11. Fix `refreshEntitlements` race with product loading
Fixed in commit `f296a83` — `if products.isEmpty { await loadProducts() }` guard added.

### ✅ 12. Fix iPhone SE layout — lifetime card overflow
Fixed in commit `6abcf56` — `ViewThatFits` wraps the two lifetime stats into HStack (wide) / VStack (narrow).

### ✅ 13. Change `armv7` to `arm64` in Info.plist
Fixed in commit `f296a83`.

---

## 🟡 MEDIUM — Fix before public launch

### ⬜ 14. Implement DeviceActivityMonitor — wire real usage data
**File:** `DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`

`eventDidReachThreshold` is still empty. The shield shows "0 min today" because `todaySeconds_<token>` is never written. Implement to write per-app seconds to SharedDefaults so the impact screen shows real numbers.

### ✅ 15. Wire up SharedDefaults.updateWidgetSnapshot()
Fixed in commit `f296a83` — called from `DashboardView.onAppear` and `OverrideTracker.recordOverride`.

### ✅ 16. Initiate StoreKit trial at end of onboarding
Fixed — `finishOnboarding()` now sets `showPaywall = true`; PaywallView sheet appears after the summary step. `AuthorizationManager.markOnboardingComplete()` is called on sheet dismiss so the `hasCompletedOnboarding` flag gates the Dashboard transition. Manual test: TESTING.md §2.

### ✅ 17. Remove shields when subscription lapses
Fixed in commit `f296a83` — `AppBlocker.removeAll()` called in `refreshEntitlements` when `activeSubscription == nil`.

### ✅ 18. Fix PaywallView feature copy
Fixed in commit `f296a83` — "FamilyControls — unkillable" → "System-level blocking — apps can't override it".

### ✅ 19. Show trial eligibility on paywall CTA
Fixed — `.task(id: selectedProductID)` calls `product.subscription?.isEligibleForIntroOffer`; CTA changes to "Subscribe — $X.XX" and header drops "14 days free" when ineligible. Manual test: TESTING.md §8.10–8.11.

### ✅ 20. Fix DeviceActivitySchedule end time
Fixed in commit `f296a83` — `intervalEnd: DateComponents(hour: 23, minute: 59, second: 59)`.

### ⬜ 21. Move override log to Keychain
**File:** `DoomScroll/Models/OverrideTracker.swift`

The override limit (the core security control) lives in an unencrypted App Group plist. On a jailbroken device, deleting this key bypasses the daily limit. Move `overrideLog` to a Keychain item shared via a Keychain Access Group (`keychain-access-groups` entitlement).

### ⬜ 22. Move UserProfile to Keychain
**File:** `DoomScroll/Models/UserProfile.swift`

Birth year + gender stored in plaintext in the App Group plist — exposed via unencrypted iTunes/iCloud backups. Move to Keychain with `kSecAttrAccessibleAfterFirstUnlock`.

### ✅ 23. Fix SharedDefaults.store — remove force unwrap, cache the instance
Fixed in commit `f296a83` — `static let store` with `assertionFailure` fallback.

### ✅ 24. Fix calendar-year age arithmetic
Fixed — `UserProfile.currentAge` now uses `Calendar.dateComponents([.year], from:to:)` with birth date approximated as January 1 of `birthYear`. Accurate to within 0–364 days; sufficient for age-group bucketing.

---

## 🔧 MANUAL PREREQUISITES — Required before device testing or App Store submission

These are not code tasks. They must be done in Apple's portals or external services.

### M1. Fill in your Apple Developer Team ID
**File:** `project.yml` — find `DEVELOPMENT_TEAM: ""` and replace with your 10-character Team ID.
Find it at: developer.apple.com → Account → Membership Details → Team ID.
**Needed before:** `xcodegen generate` produces a buildable project.

### M2. Register App IDs and App Group in Apple Developer portal
At developer.apple.com → Certificates, Identifiers & Profiles → Identifiers, register:

| Identifier | Type |
|---|---|
| `com.doomscroll.app` | App ID — enable App Groups + Family Controls |
| `com.doomscroll.app.ShieldConfiguration` | App ID — enable App Groups |
| `com.doomscroll.app.ShieldAction` | App ID — enable App Groups |
| `com.doomscroll.app.DeviceActivityMonitor` | App ID — enable App Groups |
| `com.doomscroll.app.Widget` | App ID — enable App Groups |
| `group.com.doomscroll` | App Group — link to all five App IDs above |

**Needed before:** any build reaches a physical device.

### M3. Create App Store Connect app listing
At appstoreconnect.apple.com:
1. Create a new app with bundle ID `com.doomscroll.app`
2. Create the four In-App Purchase subscription products:
   - `com.doomscroll.individual.monthly` — $4.99/mo, 14-day free trial, Family Sharing: off
   - `com.doomscroll.individual.annual` — $39.99/yr, 14-day free trial, Family Sharing: off
   - `com.doomscroll.family.monthly` — $7.99/mo, 14-day free trial, Family Sharing: on
   - `com.doomscroll.family.annual` — $69.99/yr, 14-day free trial, Family Sharing: on
3. Create a subscription group named `doomscroll_premium` and add all four products to it

**Needed before:** StoreKit products load in the app (even with the local `.storekit` config for testing, the App Store Connect IDs must match for TestFlight/production).

### M4. Write and host the privacy policy
Required for App Store submission metadata. See task #6 above for details.

---

## 🔵 FEATURE — Planned but not yet built

### 25. Implement real DeviceActivity usage tracking
Real per-app usage via `DeviceActivityReport`. Currently all numbers are placeholders (`3 * 3600 * 365`).

### 26. Wire up the AI reflection engine (iOS 26 / Foundation Models)
`AIReflectionEngine` is a stub. Implement `LanguageModelSession` calls guarded by `#available(iOS 26.0, *)` and the hardware capability check. Fall back to static `ReflectionEngine.swift` prompts for older devices.

### 27. Parent → child device control (family authorization mode)
Switch from `.individual` to `.family` authorization for true parental control. Also enables the proper "block all except one app" allowlist primitive for Focus Mode.

### 28. ✅ Streak persistence
Done in commit `f296a83` — real streak tracking via `OverrideTracker`, incremented at midnight by DeviceActivityMonitor, reset on override-limit exhaustion.

### 29. Push notifications for streaks and check-ins
Optional daily check-in + streak milestone notifications via `UNUserNotificationCenter`. Max 1/day, default off, user opts in.

### 30. Session time budget selection in the override flow
Currently hardcoded 15 minutes. Let user choose 15/30/45 min via an additional `.defer` cycle or a local notification to open the main app.

### 31. Focus Mode — true "block everything" via .family authorization
Requires `.family` authorization (see #27). Enables `shield.applicationCategories = .all()` with specific apps explicitly exempted.

### 32. watchOS companion app
Apple Watch face showing Square Eyes expression + remaining focus time + today's streak.

### 33. ✅ Remove dead code — `ShieldConversationState.overridesToday`
Done in commit `f296a83` — field removed.

---

## Audit source reference

| Code | Source |
|---|---|
| S* | Security audit |
| H* | Hardware/compatibility audit |
| C* | Code correctness audit |
| A* | App Store compliance audit |
