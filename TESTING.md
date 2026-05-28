# DoomScroll — Test Plan

## Automated tests (run in Xcode, no device required)

After running `xcodegen generate`, select the **DoomScrollTests** scheme and press ⌘U.

| File | Coverage |
|---|---|
| `OverrideTrackerTests.swift` | Override counting, daily limit, atomic `attemptOverride`, per-token isolation, streak increment/break/advance |
| `LifetimeImpactCalculatorTests.swift` | Year projection math, daily average, relational stake text for all age×gender combos, `durationString` helper |
| `UserProfileTests.swift` | `ageGroup` bucket boundaries, `yearsRemaining` including edge cases, Codable round-trip, save/load |
| `ShieldConversationStateTests.swift` | Default values, Codable round-trip for all three steps, save/load isolation per token, `sessionBudgetSeconds = 900` at commit |
| `ReflectionEngineTests.swift` | All 9 age×gender combinations produce non-empty prompts, app name injected, today-minutes injected, non-judgmental tone |

---

## Manual tests — physical iPad required

FamilyControls, ManagedSettings, DeviceActivity, and WidgetKit cannot be tested in Simulator. Run these on your iPad after following SETUP.md.

---

### Before you start

- [ ] FamilyControls entitlement approved by Apple (TODO #3 / M2)
- [ ] App IDs and App Group registered in Apple Developer portal (TODO M2)
- [ ] App built and running on device (`⌘R` in Xcode with your iPad connected)
- [ ] Screen Time permission granted (Settings → Screen Time → DoomScroll)

---

### 1. Authorization flow

| # | Step | Expected |
|---|---|---|
| 1.1 | Fresh install: open app | Authorization screen shown with Square Eyes (concerned expression) |
| 1.2 | Tap "Grant Screen Time access" | iOS Screen Time permission dialog appears |
| 1.3 | Deny permission | Error message appears below the button ("Screen Time permission was denied...") — button remains tappable |
| 1.4 | Tap button again after denying | Dialog appears again (or Settings deeplink) |
| 1.5 | Grant permission | App advances to Onboarding |

---

### 2. Onboarding

| # | Step | Expected |
|---|---|---|
| 2.1 | Complete onboarding: enter birth year, select gender | Profile saved, onboarding advances |
| 2.2 | Select apps to restrict via picker | Apps appear in managed-apps list |
| 2.3 | Tap "Start my 14-day trial" on summary step | PaywallView sheet appears |
| 2.4 | Dismiss paywall (tap anywhere or cancel) without purchasing | Dashboard shown — `hasCompletedOnboarding = true` |
| 2.5 | Kill app and reopen | Dashboard shown (not onboarding again) |
| 2.6 | Complete purchase in paywall during onboarding | Dashboard shown, `hasActiveAccess = true` |

---

### 3. Shield friction flow (core feature)

Add a test app (e.g., Safari) to the friction list, then test the full conversation.

| # | Step | Expected |
|---|---|---|
| 3.1 | Go to home screen and tap a shielded app | DoomScroll shield appears (not the iOS default block screen) |
| 3.2 | Impact screen: correct app name shown | ✓ App name in title |
| 3.3 | Impact screen: override count shown ("2 overrides left today") | ✓ Correct count |
| 3.4 | Tap "Not right now" (secondary button) | Shield dismisses, app stays blocked |
| 3.5 | Tap shielded app again | Impact screen shows again (state reset) |
| 3.6 | Tap primary button ("Open it anyway") | Reflection screen appears (no flicker) |
| 3.7 | Reflection screen: question shown, correct for age/gender | ✓ Non-empty, appropriate tone |
| 3.8 | Tap "Actually, never mind" (secondary) | Shield dismisses, app stays blocked, state reset |
| 3.9 | Repeat steps 3.5–3.6, then tap primary on reflection screen | Commit screen appears |
| 3.10 | Commit screen: "Start 15-min session" button shown | ✓ Override count decremented by 1 |
| 3.11 | Tap "Stay closed" (secondary on commit) | Shield dismisses, app stays blocked |
| 3.12 | Repeat full flow to commit, tap "Start 15-min session" | App opens immediately |
| 3.13 | Within 15 minutes: try to open the app again | App opens freely (session still active) |
| 3.14 | After 15 minutes: try to open the app | Shield appears again |

---

### 4. Override limit enforcement

| # | Step | Expected |
|---|---|---|
| 4.1 | Use both overrides for an app (complete flow twice) | Remaining = 0 |
| 4.2 | Attempt to open shielded app with 0 overrides | Impact screen shows "Stay closed" (not "Open anyway") |
| 4.3 | Tap primary button on exhausted impact screen | Shield dismisses cleanly — no flicker, app stays blocked |
| 4.4 | Dashboard → streak card → override dots | Both dots filled (amber) |
| 4.5 | Kill app, reopen, check override dots | Dots still filled (persisted in SharedDefaults) |
| 4.6 | Midnight reset (or manually clear override log for testing) | Overrides reset to 2 |

---

### 5. Streak tracking

| # | Step | Expected |
|---|---|---|
| 5.1 | Open Dashboard after a day with no overrides used | Streak increments by 1 vs previous day |
| 5.2 | Exhaust all overrides for any app | Streak immediately resets to 0 |
| 5.3 | Dashboard shows correct streak count | Matches SharedDefaults.streakCount |
| 5.4 | Streak card subtitle shows personal best | "Your best: X days" when streak < best |
| 5.5 | Mascot expression on Dashboard | proud (streak > 5), happy (streak > 0), idle (streak = 0) |

---

### 6. Focus Mode

| # | Step | Expected |
|---|---|---|
| 6.1 | Tap "Focus" in Dashboard toolbar | Focus Mode sheet appears |
| 6.2 | Select focus app (e.g., Notes) via app picker | App name shown in the selected-app row |
| 6.3 | Choose duration (25 min chip) | Duration selected, confirmed in summary |
| 6.4 | Tap "Start focus" | Session begins; ActiveFocusView embedded in Dashboard |
| 6.5 | Go home screen, open any non-focus app | Focus shield appears ("You're in focus mode. Go back to [app].") |
| 6.6 | Tap "Back to [focus app]" on shield | Shield dismisses |
| 6.7 | Open the focus app itself | Opens freely (no shield) |
| 6.8 | Return to DoomScroll, tap "End session early" | Friction step 1: reflection question |
| 6.9 | Answer reflection, tap confirm | Session ends, shields removed |
| 6.10 | Session expires naturally at 25 min | Shields removed, Dashboard shows session ended |

---

### 7. Widget

| # | Step | Expected |
|---|---|---|
| 7.1 | Add small DoomScroll widget to home screen | Square Eyes + streak flame + "X% reclaimed" visible |
| 7.2 | Add medium widget | Square Eyes + relational stake text + progress ring + override dots |
| 7.3 | Use an override in the app | Widget refreshes within 15 min, shows reduced override dots |
| 7.4 | Widget expression: streak > 6 | proud expression |
| 7.5 | Widget expression: streak > 2 or reclaimed > 70% | happy expression |
| 7.6 | Widget expression: 0 overrides left | sleepy expression |

---

### 8. Subscription and paywall

Run these using the StoreKit sandbox. Make sure `DoomScroll.storekit` is selected in the scheme's Run options (SETUP.md step 7).

| # | Step | Expected |
|---|---|---|
| 8.1 | Open Paywall (e.g., tap "+" for more apps) | Paywall shown with Square Eyes, tier picker, period picker |
| 8.2 | Toggle Individual / Family tiers | Price card updates, feature list updates |
| 8.3 | Toggle Annual / Monthly | Price card updates, "Save 40%" badge on Annual |
| 8.4 | Price shown correctly | Matches selected product's `displayPrice` |
| 8.5 | Footer shows full auto-renewal disclosure | Required Apple language present with price |
| 8.6 | Tap "Start 14-day free trial" | StoreKit sandbox purchase sheet appears |
| 8.7 | Complete sandbox purchase | Paywall dismisses, `hasActiveAccess = true`, app usable |
| 8.8 | Tap "Restore" | Purchases restored if previously purchased |
| 8.9 | Cancel purchase mid-flow | Paywall stays open, no error shown |
| 8.10 | Open paywall after previously using a free trial (sandbox: refund then reopen) | CTA reads "Subscribe — $X.XX" not "Start 14-day free trial"; subtitle omits "14 days free" |
| 8.11 | Open paywall with no prior trial | CTA reads "Start 14-day free trial"; subtitle includes "14 days free" |

---

### 9. Regression — Settings and data

| # | Step | Expected |
|---|---|---|
| 9.1 | Settings → change life expectancy | Lifetime card updates on Dashboard |
| 9.2 | Settings → check plan name shown | Correct plan (e.g., "Family Annual") |
| 9.3 | Force-quit app, reopen | All managed apps still shielded |
| 9.4 | Delete and reinstall app | Authorization request shown again |

---

### 10. Edge cases

| # | Step | Expected |
|---|---|---|
| 10.1 | Double-tap the primary button rapidly on impact screen | Override recorded exactly once (atomic `attemptOverride`) |
| 10.2 | Open a shielded app while focus mode is active | Focus shield shown (not the standard override flow) |
| 10.3 | Subscription lapses (use StoreKit sandbox refund) | Shields removed automatically |
| 10.4 | Device in dark mode | App forces light mode (all colors correct) |
| 10.5 | Run on iPhone SE (375 pt width) | Lifetime card stats stack vertically, no overflow |

---

## CI / automated test execution

The XCTest suite can be run headlessly on a simulator from the command line once `xcodegen generate` has been run:

```bash
xcodebuild test \
  -project DoomScroll.xcodeproj \
  -scheme DoomScrollTests \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  | xcpretty
```

This covers all tests that don't require FamilyControls. Run it before every commit that touches business logic.
