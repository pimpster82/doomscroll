# DoomScroll — Setup Guide

Getting the app running on your iPad from scratch. Estimated time: 2–3 hours, mostly waiting on Apple.

---

## What you need before you start

| Requirement | Notes |
|---|---|
| Mac running macOS 14 (Sonoma) or later | Xcode requires a Mac — no way around this |
| Xcode 16 or later | Free from the Mac App Store |
| Apple Developer account | Paid, $99/year at developer.apple.com |
| Your iPad on iPadOS 18.0 or later | Settings → General → About to check |
| A USB cable or reliable Wi-Fi | For deploying to the device |
| This repo cloned to your Mac | `git clone <repo-url>` |

---

## Step 1 — Install xcodegen

xcodegen turns the `project.yml` file in this repo into a proper Xcode project. You only need to do this once (and again whenever `project.yml` changes).

```bash
# Install Homebrew if you don't have it:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install xcodegen:
brew install xcodegen
```

---

## Step 2 — Request the FamilyControls entitlement from Apple

**This step has a wait time of 1–5 business days. Do it first.**

FamilyControls is a restricted API. Apple must manually approve your app before you can use it, even for personal/development builds.

1. Go to: https://developer.apple.com/contact/request/family-controls-distribution
2. Log in with your Apple Developer account
3. Fill in the form:
   - **App name:** DoomScroll
   - **Bundle ID:** `com.doomscroll.app` (or your own — see Step 4)
   - **Use case:** "Screen time friction app for individuals and families. Uses FamilyControls to shield selected apps and require a reflection conversation before the user can open them. No parental control of other devices — individual use only."
4. Submit and wait. You'll get an email when approved.

**You cannot test the app on a real device without this approval.** The Simulator won't work for FamilyControls either.

---

## Step 3 — Set up your Bundle ID and App Group

You need to register identifiers in your Apple Developer account. All of these must match the values in the project.

### 3a. Choose your bundle ID prefix

The project uses `com.doomscroll` as the prefix. You can keep this or change it to something like `com.yourname.doomscroll`. Whatever you choose, use it consistently everywhere below.

If you change the prefix, do a project-wide find-and-replace of `com.doomscroll` with your prefix in `project.yml` before generating the Xcode project.

### 3b. Register identifiers at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers

Register these five App IDs (type: App, platform: iOS):

| Identifier | Description |
|---|---|
| `com.doomscroll.app` | Main app |
| `com.doomscroll.app.ShieldConfiguration` | Shield UI extension |
| `com.doomscroll.app.ShieldAction` | Shield action extension |
| `com.doomscroll.app.DeviceActivityMonitor` | Usage monitor extension |
| `com.doomscroll.app.Widget` | Home screen widget |

For the main app identifier (`com.doomscroll.app`), enable these capabilities:
- ✅ App Groups
- ✅ Family Controls *(only available after Apple approves your entitlement request from Step 2)*

For all five identifiers, enable:
- ✅ App Groups

### 3c. Register the App Group

Go to Identifiers → App Groups → + → name it exactly:

```
group.com.doomscroll
```

Then go back to each of the five App IDs above and link this App Group to each one.

---

## Step 4 — Find your Team ID

1. Go to developer.apple.com → Account → Membership
2. Copy your **Team ID** — it looks like `ABC1234567`

---

## Step 5 — Generate the Xcode project

In Terminal, navigate to the repo folder:

```bash
cd path/to/doomscroll

# Open project.yml and set your Team ID:
# Find the line:  DEVELOPMENT_TEAM: ""
# Change it to:   DEVELOPMENT_TEAM: "ABC1234567"  (your actual Team ID)

# If you changed your bundle prefix in Step 3, do the find-replace now.

# Generate the project:
xcodegen generate

# Open in Xcode:
open DoomScroll.xcodeproj
```

---

## Step 6 — Configure signing in Xcode

1. In Xcode, select the `DoomScroll` project in the left sidebar (the blue icon at the top)
2. For each of the **five targets** (DoomScroll, ShieldConfigurationExtension, ShieldActionExtension, DeviceActivityMonitorExtension, DoomScrollWidget):
   - Click the target
   - Go to **Signing & Capabilities**
   - Under **Signing**, set **Team** to your Apple Developer account
   - Tick **Automatically manage signing**
   - Xcode will create provisioning profiles for you

If you see an error about App Groups or FamilyControls, make sure Step 3 is complete and the identifiers are registered.

---

## Step 7 — Add the StoreKit configuration (for testing subscriptions)

The `DoomScroll.storekit` file in the repo lets you test all four subscription tiers without real money.

1. In Xcode, go to **Product → Scheme → Edit Scheme** (or ⌘<)
2. Select **Run** in the left panel
3. Go to the **Options** tab
4. Under **StoreKit Configuration**, click the dropdown and select `DoomScroll.storekit`
5. Click Close

Now when you run the app, tapping any subscription option will use the test products — no charge.

---

## Step 8 — Connect your iPad and run

1. Connect your iPad to your Mac with a cable (or via Wi-Fi — Xcode → Window → Devices and Simulators → your iPad → Connect via Network)
2. On your iPad, go to **Settings → Privacy & Security → Developer Mode** and enable it (requires a restart)
3. In Xcode, select your iPad from the device picker at the top (next to the scheme name)
4. Press **⌘R** to build and run

On first run on the iPad:
- iOS will ask if you trust the developer — go to **Settings → General → VPN & Device Management** and tap Trust
- The app will open and ask for Screen Time permission — grant it
- Go through the onboarding: pick your birth year, gender, apps to restrict

---

## Step 9 — Test the friction flow

To test that the shield works:

1. In the app, add an app to your friction list (e.g., Safari)
2. Go to your iPad home screen
3. Tap Safari
4. The DoomScroll shield should appear with Square Eyes and the impact message
5. Tap through the conversation steps
6. Confirm the session opens with the "15-min session" commit

If the shield doesn't appear, check:
- Screen Time is granted (Settings → Screen Time → DoomScroll)
- The app is actually in your shield list in DashboardView

---

## Step 10 — Test Focus Mode

1. In the app, tap **Focus** in the top-left of the dashboard
2. Pick an app you want to focus with (e.g., Notes or a writing app)
3. Set a short duration (25 min)
4. Tap the DND reminder — manually enable Focus/DND in Control Centre
5. Go to your home screen — try to open any other app; it should be shielded with the focus overlay
6. Return to DoomScroll — the countdown timer should be visible
7. Test the early-exit friction: tap "End session early" and go through the two-step conversation

---

## Step 11 — Add to your home screen as a widget

1. Long-press the iPad home screen until icons jiggle
2. Tap the **+** in the top-left
3. Search for "DoomScroll"
4. Choose Small or Medium widget
5. Place it on your home screen
6. The widget will show Square Eyes' current expression based on today's session data

*Note: the widget refreshes every 15 minutes. Real usage data requires the DeviceActivity integration to be implemented (see TODO.md).*

---

## Step 12 — Share with family (Family plan)

Once you have a subscription set up:

1. Make sure your family members are in your **Apple Family Sharing** group (Settings → Your Name → Family Sharing)
2. You purchase the **Family Annual** plan ($89.99/yr)
3. Open the DoomScroll app on each family member's device — they'll automatically have access through Family Sharing
4. Each family member sets up their own profile and friction list independently

For parent → child device control (locking a child's device), that requires the `.family` authorization mode — see TODO.md for the implementation task.

---

## Troubleshooting

**"Missing entitlement" error on build:**
The FamilyControls entitlement hasn't been approved yet, or the App Group isn't linked to your identifier. Re-check Step 2 and 3.

**Shield doesn't appear when opening a shielded app:**
- Check Settings → Screen Time → Content & Privacy Restrictions is on
- Check the app is actually in your managed list in DashboardView
- Try revoking and re-granting Screen Time permission in AuthorizationView

**Widget shows 0% reclaimed, 0 day streak:**
The `DeviceActivityMonitor` integration is not yet implemented — see TODO.md item #7. The widget works but shows placeholder data until real usage data is wired up.

**StoreKit sandbox purchase fails:**
Make sure the `DoomScroll.storekit` configuration is selected in your scheme (Step 7). The products won't load without it in development.

**"Untrusted developer" on iPad:**
Settings → General → VPN & Device Management → your Apple ID → Trust.

---

## File structure reference

```
DoomScroll/                     Main app (SwiftUI)
  App/DoomScrollApp.swift       Entry point
  Design/DesignSystem.swift     All colors, fonts, spacing
  Views/                        All screens + Square Eyes mascot
  Models/                       UserProfile, LifetimeImpact, FocusSession, OverrideTracker
  AI/ReflectionEngine.swift     Age/gender-adapted reflection prompts
  Subscriptions/                StoreKit 2 manager + paywall
  Shared/SharedDefaults.swift   App Groups shared storage

ShieldConfigurationExtension/   What the shield overlay looks like
ShieldActionExtension/          What happens when you tap the shield buttons
DeviceActivityMonitorExtension/ Background usage monitoring (stub — see TODO)
DoomScrollWidget/               Home screen widget (small + medium)

project.yml                     xcodegen project spec (edit Team ID here)
DoomScroll.storekit             Subscription products for local testing
```
