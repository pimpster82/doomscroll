# DoomScroll

A screen time app that creates friction through awareness, not hard blocks. Designed for families.

## How it works

When you try to open a shielded app, DoomScroll shows you three things before you get in:

1. **Impact** — how much time you've spent today, framed as a near-term personal stake (not abstract lifetime stats)
2. **Reflection** — one question adapted to your age and gender, designed to make the decision conscious rather than automatic
3. **Commit** — you set a session time limit; the app re-shields itself when it runs out

You get **2 override conversations per app per day**. After that, the app stays locked until midnight.

## Project structure

```
DoomScroll/                         Main app (SwiftUI)
  App/DoomScrollApp.swift           Entry point, FamilyControls authorization
  Views/OnboardingView.swift        4-step setup: profile + app picker
  Views/DashboardView.swift         Daily stats + lifetime projection (hidden by default)
  Views/SettingsView.swift          Edit profile
  Models/UserProfile.swift          Age, gender, life expectancy — stored on-device
  Models/LifetimeImpactCalculator   Near-term + lifetime impact math
  Models/OverrideTracker.swift      Daily override counter (max 2/app)
  Models/AppBlocker.swift           ManagedSettings wrapper
  AI/ReflectionEngine.swift         Age/gender-adapted reflection prompts
  Shared/SharedDefaults.swift       App Groups keys shared with extensions

ShieldConfigurationExtension/       Renders the 3-step shield UI
ShieldActionExtension/              Handles button taps, drives conversation state machine
DeviceActivityMonitorExtension/     Background usage monitoring
```

## Building on macOS

### Prerequisites

- Xcode 16+
- Apple Developer account (paid, $99/yr)
- FamilyControls entitlement — request at [developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution)
- `xcodegen` — `brew install xcodegen`

### Setup

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2. Open in Xcode
open DoomScroll.xcodeproj

# 3. Set your Development Team in project.yml (DEVELOPMENT_TEAM) and re-run xcodegen

# 4. Update App Group IDs if needed:
#    Replace "group.com.doomscroll" everywhere with your actual bundle prefix

# 5. Build and run on a real device (FamilyControls does not work in Simulator)
```

### App Store submission checklist

- [ ] FamilyControls entitlement approved by Apple
- [ ] Privacy policy covering Screen Time data (required)
- [ ] COPPA compliance if targeting users under 13
- [ ] Age rating: minimum 4+ (parental controls), adjust if content warrants higher

## Conversation design

The reflection questions are age- and gender-adapted based on behavioral research:

| Group | Frame | What works |
|---|---|---|
| Teens | Autonomy vs algorithm | "These apps are built to hook you — what are you actually after?" |
| Young adults | Concrete opportunity cost | "That's 40 min. What are you trading it for?" |
| Mid-life | Near-term relational stakes | "Your kid is 11. You have ~7 summers left." |

**What the research says not to do:** shame spirals, parental tone, hard blocks with no escape, abstract lifetime statistics as the primary frame.

## On-device AI (planned)

iOS 26 + iPhone 15 Pro and newer: Apple Foundation Models framework generates dynamic reflection questions personalized to the user's stated goals and recent override patterns.

iOS 18 fallback: bundled 1B INT4 CoreML model (Phi-3-mini or Llama-3.2-1B). Feasible on iPhone 12 and later.

The static prompts in `ReflectionEngine.swift` are the current fallback and ship as the v1 baseline.

## Family mode

FamilyControls supports a `.family` authorization mode where a parent's device manages restrictions on a child's device via Apple Family Sharing (up to 6 members). iOS 26 adds a `Declared Age Range API` that lets parents share the child's age bracket with apps — used here to auto-select the appropriate conversation tone without asking teens for their own age.
