# DoomScroll — Open Tasks

Findings from security, hardware, code correctness, and App Store compliance audits,
plus known feature gaps. Ordered by priority within each section.

---

## 🔴 CRITICAL — Fix before any device testing

These are broken right now. The app won't behave correctly without them.

### 1. Set sessionBudgetSeconds before committing an override
**File:** `ShieldActionExtension/ShieldActionExtension.swift` and `DoomScroll/Shared/SharedDefaults.swift`

`ShieldConversationState.sessionBudgetSeconds` is never written. The commit screen says "15-min session" but the re-shield never fires because `scheduleBudgetReblock` receives `seconds: 0` and returns early. The 15-minute lock is cosmetic only.

**Fix:** In `ShieldActionExtension.handlePrimary`, when advancing from `.reflection` to `.commit`, set `state.sessionBudgetSeconds = 900`. Or let the user choose their session length (15/30/45 min) and write the selected value.

---

### 2. Fix wrong `.defer` response when overrides are exhausted
**File:** `ShieldActionExtension/ShieldActionExtension.swift:44`

When `OverrideTracker.canOverride` returns `false`, the code calls `completionHandler(.defer)`. This re-renders the shield UI on top of itself creating a flicker loop. It should call `completionHandler(.close)` to simply dismiss and keep the app blocked.

**Fix:** Change line 44 from `.defer` to `.close`.

---

### 3. Apply for the FamilyControls entitlement from Apple
**Not a code change — an Apple portal action.**

Without this, the binary is rejected before a human reviewer sees it. The entitlement form is at:
https://developer.apple.com/contact/request/family-controls-distribution

Also add error feedback in `AuthorizationView.swift` for when `requestAuthorization()` throws — currently the button silently fails and the app is stuck on the authorization screen forever.

---

## 🟠 HIGH — Fix before App Store submission

### 4. Fix dark mode (add `.preferredColorScheme(.light)`)
**File:** `DoomScroll/App/DoomScrollApp.swift`

All colors in `DesignSystem.swift` are fixed hex values with no dark/light adaptive variants. In system dark mode the app shows a broken hybrid: light-coloured content inside dark system chrome (navigation bar, status bar, keyboard). The minimum fix is to force light mode intentionally:

```swift
// In DoomScrollApp.body:
WindowGroup { ... }
    .preferredColorScheme(.light)
```

Long-term: add dark-adaptive `Color` values using `Color(uiColor: UIColor { traitCollection in ... })` in DesignSystem.

---

### 5. Add required auto-renewal disclosure to PaywallView
**File:** `DoomScroll/Subscriptions/PaywallView.swift`

Apple requires specific language near the purchase button. Add this to the `footer` view, replacing the current vague text:

> Payment will be charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings. Any unused portion of a free trial is forfeited on purchase.

Also display the exact price and billing period from `selectedProduct.displayPrice` alongside the billing frequency.

---

### 6. Add a privacy policy and `NSPrivacyPolicyURL`
**Files:** `DoomScroll/Info.plist`, `DoomScroll/Views/SettingsView.swift`

Apps collecting personal data (birth year, gender) require a privacy policy URL. Without it, App Store submission fails at metadata review.

- Write a privacy policy (host it at a stable URL — GitHub Pages works)
- Add `NSPrivacyPolicyURL` key to `Info.plist` pointing to that URL
- Add a tappable "Privacy Policy" link in `SettingsView.aboutSection`

---

### 7. Create `PrivacyInfo.xcprivacy` manifest
**New file:** `DoomScroll/PrivacyInfo.xcprivacy`

Required since Spring 2024 for all apps using "required reason APIs." DoomScroll uses `UserDefaults` (reason category `CA92.1`) and `Date()` (category `35F9.1`). Without this file, App Store submission is rejected automatically.

Create the file in Xcode: File → New → File → Privacy Manifest. Declare:
- `NSPrivacyAccessedAPITypes`:
  - `UserDefaults` — reason `CA92.1` (app functionality)
  - `FileTimestamp` — reason `35F9.1` (app functionality)
- `NSPrivacyCollectedDataTypes`: birth year (age range), gender — linked to: false, tracking: false

---

### 8. Fix SquareEyesView blink timer orphan
**File:** `DoomScroll/Views/SquareEyesView.swift:231–240`

When the view disappears mid-blink, the `DispatchQueue.main.asyncAfter(+0.12s)` block still fires and calls `scheduleNextBlink()`, creating a new timer on a view that's left the hierarchy. Fix:

```swift
@State private var isVisible = false

.onAppear { isVisible = true; startBreathing(); startBlinking() }
.onDisappear { isVisible = false; blinkTimer?.invalidate() }

// In scheduleNextBlink():
guard isVisible else { return }
```

---

### 9. Change `@StateObject` to `@ObservedObject` for singletons
**Files:** `DoomScroll/Subscriptions/PaywallView.swift:8`, `DoomScroll/App/DoomScrollApp.swift`

`@StateObject` is for objects created by the view. Using it with a pre-existing singleton (`SubscriptionManager.shared`, `FocusModeManager.shared`) is semantically wrong. Change to `@ObservedObject`. The app-level ones in `DoomScrollApp.swift` can stay as `@StateObject` since the app creates them, but `PaywallView` should use `@ObservedObject`.

---

### 10. Fix OverrideTracker TOCTOU race condition
**File:** `DoomScroll/Models/OverrideTracker.swift`

`canOverride` and `recordOverride` are two separate read/write operations — a rapid double-tap could allow more than 2 overrides. Combine into one atomic function:

```swift
// Replace canOverride + recordOverride call sites with:
static func attemptOverride(for tokenString: String) -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    var current = log
    var timestamps = (current[tokenString] ?? []).filter { $0 >= today }
    guard timestamps.count < maxOverridesPerDay else { return false }
    timestamps.append(Date())
    current[tokenString] = timestamps
    log = current
    return true
}
```

---

### 11. Fix `refreshEntitlements` race with product loading
**File:** `DoomScroll/Subscriptions/SubscriptionManager.swift:116–123`

If a `Transaction.updates` event fires before `loadProducts()` completes, `products.first { $0.id == transaction.productID }` returns `nil` and the user is incorrectly shown as unsubscribed.

```swift
func refreshEntitlements() async {
    if products.isEmpty { await loadProducts() }  // add this guard
    // ... rest of function
}
```

---

### 12. Fix iPhone SE layout — lifetime card overflow
**File:** `DoomScroll/Views/DashboardView.swift:177–196`

Two 56pt bold numbers side-by-side in an `HStack` overflow on 375pt screens. Change to a `VStack` layout for the lifetime card, or reduce font size to `DS.Font.title` with `minimumScaleFactor(0.7)`.

---

### 13. Change `armv7` to `arm64` in Info.plist
**File:** `DoomScroll/Info.plist:34`

`armv7` is 32-bit ARM from 2013. iOS 18 cannot run on any armv7 device. Change to `arm64` or remove the key entirely (the deployment target already enforces the hardware floor).

---

## 🟡 MEDIUM — Fix before public launch

### 14. Implement DeviceActivityMonitor — wire real usage data
**File:** `DoomScroll/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`

All monitor override stubs are empty. The shield always shows "0 min today" because `todaySeconds_<token>` is never written. This breaks the core value proposition — showing real usage to create friction.

Implement `eventDidReachThreshold` to write per-app today-seconds to SharedDefaults. Also implement `intervalDidStart` to reset the daily counters at midnight.

---

### 15. Wire up SharedDefaults.updateWidgetSnapshot()
**File:** `DoomScroll/Views/DashboardView.swift`, `DoomScroll/Models/OverrideTracker.swift`

`updateWidgetSnapshot(streak:reclaimedPercent:overridesLeft:)` exists but is never called. The widget always shows 0 for everything. Call it:
- In `DashboardView.onAppear` and after any state change
- After each override in `OverrideTracker.recordOverride`

Also implement `DashboardView.overridesUsedToday` (currently returns hardcoded `0`) by aggregating `OverrideTracker.overridesToday` across all managed app tokens.

---

### 16. Initiate StoreKit trial at end of onboarding
**File:** `DoomScroll/Views/OnboardingView.swift:246–251`

`finishOnboarding()` calls `AppBlocker.apply()` but never initiates a StoreKit purchase. So `hasActiveAccess` is `false` immediately after onboarding, and the user hits the paywall when they try to add more apps. Either:
- Show the paywall as the final onboarding step (after the summary), or
- Add a 24-hour grace period before gating features, or
- Make the app picker permanently free (only gate AI/analytics features)

---

### 17. Remove shields when subscription lapses
**File:** `DoomScroll/Subscriptions/SubscriptionManager.swift`, `DoomScroll/Models/AppBlocker.swift`

If a user's subscription expires, `hasActiveAccess` becomes `false` but the shields applied during onboarding remain active forever. Add to `refreshEntitlements()`:

```swift
if activeSubscription == nil {
    AppBlocker.removeAll()
}
```

---

### 18. Fix PaywallView feature copy — remove implied FamilyControls paywall
**File:** `DoomScroll/Subscriptions/PaywallView.swift:182`

The bullet `"FamilyControls — unkillable by the apps"` implies FamilyControls is a paid feature, which violates App Store guideline 3.1.3. Change to something like `"System-level blocking — apps can't override it"`.

---

### 19. Show trial eligibility on paywall CTA
**File:** `DoomScroll/Subscriptions/PaywallView.swift`

Check `product.subscription?.introductoryOffer` eligibility before showing "Start 14-day free trial." Users who previously subscribed and cancelled are not eligible for a second trial — showing the trial CTA to them is misleading. Fall back to "Subscribe" for ineligible users.

---

### 20. Fix DeviceActivitySchedule end time
**File:** `DoomScroll/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift:43`

Schedule ends at `23:59` leaving the last minute of each day unmonitored and causing a 1-minute gap in the daily reset cycle.

```swift
intervalEnd: DateComponents(hour: 23, minute: 59, second: 59)
```

---

### 21. Move override log to Keychain
**File:** `DoomScroll/Models/OverrideTracker.swift`

The override limit (the core security control) lives in an unencrypted App Group plist. On a jailbroken device, deleting this key bypasses the daily limit entirely. Move `overrideLog` to a Keychain item shared across targets via a Keychain Access Group (`keychain-access-groups` entitlement).

---

### 22. Move UserProfile to Keychain
**File:** `DoomScroll/Models/UserProfile.swift`

Birth year + gender + life expectancy are stored in plaintext in the App Group plist. While the app promises "nothing leaves your device," unencrypted iTunes/iCloud backups expose this data. Move to Keychain with `kSecAttrAccessibleAfterFirstUnlock` so extensions can still read it.

---

### 23. Fix SharedDefaults.store — remove force unwrap, cache the instance
**File:** `DoomScroll/Shared/SharedDefaults.swift:7–9`

Two issues:
1. The computed property allocates a new `UserDefaults` object on every call — change to `static let`
2. The `!` force-unwrap crashes all extensions silently if the App Group entitlement is misconfigured

```swift
// Replace:
static var store: UserDefaults { UserDefaults(suiteName: suiteName)! }

// With:
static let store: UserDefaults = {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        assertionFailure("App Group '\(suiteName)' not configured in entitlements")
        return .standard
    }
    return defaults
}()
```

---

### 24. Fix calendar-year age arithmetic
**File:** `DoomScroll/Models/UserProfile.swift:20`, `LifetimeImpactCalculator.swift`

`Calendar.current.component(.year, from: Date()) - birthYear` gives the age the user turns this calendar year, not their actual age (off by up to 1 year). Store birth year only (not full birth date, for privacy), and document the known approximation. Or collect birth month as well for better accuracy without exposing an exact birth date.

---

## 🔵 FEATURE — Planned but not yet built

### 25. Implement real DeviceActivity usage tracking
Currently all usage numbers are hardcoded placeholders (`3 * 3600 * 365`). Needs a proper `DeviceActivityReport` integration to pull real per-app usage over 1/7/30/365-day windows.

### 26. Wire up the AI reflection engine (iOS 26 / Foundation Models)
`AIReflectionEngine` is a stub. When iOS 26 ships, implement the `LanguageModelSession` calls guarded by `#available(iOS 26.0, *)` and the hardware capability check (`LanguageModelSession.isSupported`). Fall back to the static prompts in `ReflectionEngine.swift` for older devices.

### 27. Parent → child device control (family authorization mode)
The app currently uses `.individual` authorization. For true parental control (parent sets rules on a child's device), implement `.family` authorization mode. This also enables "block all except one app" natively — which solves the Focus Mode iOS API limitation.

### 28. Streak persistence
`streak` is hardcoded to `3` in `DashboardView`. Implement real streak tracking: increment on days where no overrides are used, reset on days where all overrides are exhausted, persist to `SharedDefaults`.

### 29. Push notifications for streaks and check-ins
Add optional daily check-in notification (morning) and streak milestone notifications. Use `UNUserNotificationCenter` with Square Eyes face as the notification attachment. Max 1 notification/day; default off; user opts in.

### 30. Session time budget selection in the override flow
Currently the commit screen hardcodes "15 minutes." Let the user choose: 15 / 30 / 45 min. This requires the shield to present a multi-option interface — use a `.defer` cycle with three different commit configurations, or send a local notification to open the main app for selection.

### 31. Focus Mode — true "block everything" via .family authorization
The current Focus Mode blocks categories + friction list but can't guarantee blocking every app. A `.family` authorization mode allows `ManagedSettings` to set `shield.applicationCategories = .all()` with specific apps explicitly exempted — which is the proper "allowlist one app" primitive. Gate this as a Family plan feature.

### 32. watchOS companion app
A simple Apple Watch face showing Square Eyes expression + remaining focus time + today's streak. Uses shared `UserDefaults` via Watch Connectivity or the shared App Group (if watch extension supports it).

### 33. Remove dead code — `ShieldConversationState.overridesToday`
The `overridesToday: Int` field in `ShieldConversationState` is never read or written. Remove it to avoid misleading future developers about where override counts are tracked (it's `OverrideTracker`, not this field).

---

## Audit source reference

| Code | Source |
|---|---|
| S* | Security audit |
| H* | Hardware/compatibility audit |
| C* | Code correctness audit |
| A* | App Store compliance audit |

Full audit reports are in the conversation history with the AI agent that built this project.
