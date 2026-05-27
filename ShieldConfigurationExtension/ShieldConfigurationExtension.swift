import ManagedSettings
import ManagedSettingsUI
import UIKit
import Foundation

// Shield overlay is intentionally dark — it sits on top of apps and must read as
// a distinct interruption. DS.Color.shieldBg (#1E1B2E warm indigo) is used throughout.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? "this app"

        // Focus mode takes priority — show a different message when a session is active.
        if isFocusModeActive() {
            return focusModeConfiguration(blockedAppName: appName)
        }

        let tokenString = application.token?.description ?? ""
        let state = ShieldConversationState.load(for: tokenString)
        let profile = UserProfile.load()
        let overridesLeft = OverrideTracker.remainingToday(for: tokenString)

        return configuration(step: state.step, appName: appName, profile: profile,
                             overridesLeft: overridesLeft, tokenString: tokenString)
    }

    override func configuration(shielding application: Application,
                                in context: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: .dsShieldBg,
            title: ShieldConfiguration.Label(text: "Take a breath.", color: .white),
            subtitle: ShieldConfiguration.Label(text: "This site is on your friction list.", color: UIColor.dsTextSecondary)
        )
    }

    // MARK: - Step configurations

    private func configuration(
        step: ShieldConversationState.ConversationStep,
        appName: String,
        profile: UserProfile?,
        overridesLeft: Int,
        tokenString: String
    ) -> ShieldConfiguration {
        switch step {
        case .impact:    return impactScreen(appName: appName, profile: profile, overridesLeft: overridesLeft, tokenString: tokenString)
        case .reflection: return reflectionScreen(appName: appName, profile: profile)
        case .commit:    return commitScreen(appName: appName, overridesLeft: overridesLeft)
        }
    }

    // Step 1: Today's time + near-term relational stake (positive framing, no shame).
    private func impactScreen(appName: String, profile: UserProfile?, overridesLeft: Int,
                               tokenString: String) -> ShieldConfiguration {
        let todaySeconds = fetchTodaySeconds(tokenString: tokenString)
        let minutes = max(0, Int(todaySeconds / 60))

        let stake: String
        if let profile {
            let calc = LifetimeImpactCalculator(profile: profile)
            stake = calc.appImpact(appName: appName, todaySeconds: todaySeconds,
                                   weeklyTotalSeconds: todaySeconds * 5).relationalStake
        } else {
            stake = minutes > 0
                ? "You've spent \(minutes) min on \(appName) today."
                : "Taking a breath before \(appName)."
        }

        let canOverride = overridesLeft > 0
        let overrideText = overridesLeft == 2 ? "Open it anyway →" :
                           overridesLeft == 1 ? "Open it (last override today) →" :
                           "No overrides left today"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: .dsShieldBg,
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: stake, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "\(overridesLeft) override\(overridesLeft == 1 ? "" : "s") left today",
                color: .dsTextSecondary
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: canOverride ? overrideText : "Stay closed",
                color: canOverride ? .white : UIColor.systemGray
            ),
            primaryButtonBackgroundColor: canOverride ? .dsShieldButton : UIColor.systemGray5,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Not right now", color: .dsTextSecondary)
        )
    }

    // Step 2: Age/gender-adapted reflective question (non-judgmental, curious tone).
    private func reflectionScreen(appName: String, profile: UserProfile?) -> ShieldConfiguration {
        let prompt: ReflectionEngine.Prompt
        if let profile {
            prompt = ReflectionEngine.prompt(for: profile, appName: appName, todaySeconds: 0)
        } else {
            prompt = ReflectionEngine.Prompt(
                question: "What are you actually after right now?",
                hint: "Be honest with yourself",
                continueLabel: "I know what I'm doing"
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: .dsShieldBg,
            icon: UIImage(systemName: "bubble.left"),
            title: ShieldConfiguration.Label(text: prompt.question, color: .white),
            subtitle: ShieldConfiguration.Label(text: prompt.hint, color: .dsTextSecondary),
            primaryButtonLabel: ShieldConfiguration.Label(text: prompt.continueLabel, color: .white),
            primaryButtonBackgroundColor: .dsShieldButton,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Actually, never mind", color: .dsTextSecondary)
        )
    }

    // Step 3: Commit to a session limit. Green accent signals positive choice, not a warning.
    private func commitScreen(appName: String, overridesLeft: Int) -> ShieldConfiguration {
        let overridesAfter = max(0, overridesLeft - 1)
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: .dsShieldBg,
            icon: UIImage(systemName: "timer"),
            title: ShieldConfiguration.Label(text: "Set your limit for this session.", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "15 minutes, then \(appName) locks again. \(overridesAfter) override\(overridesAfter == 1 ? "" : "s") left after this.",
                color: .dsTextSecondary
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start 15-min session", color: .white),
            primaryButtonBackgroundColor: .dsShieldCommit,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay closed", color: .dsTextSecondary)
        )
    }

    // MARK: - Focus mode configuration

    private func isFocusModeActive() -> Bool {
        SharedDefaults.store.bool(forKey: SharedDefaults.Key.focusModeActive)
    }

    // Shield shown for any blocked app during an active focus session.
    // Tone is entirely different: not about addiction, but protecting intentional focus.
    private func focusModeConfiguration(blockedAppName: String) -> ShieldConfiguration {
        let focusApp = SharedDefaults.store.string(forKey: SharedDefaults.Key.focusAppName) ?? "your focus"
        let endTimestamp = SharedDefaults.store.double(forKey: SharedDefaults.Key.focusEndTimestamp)
        let remaining: String = {
            guard endTimestamp > 0 else { return "" }
            let secs = max(0, endTimestamp - Date().timeIntervalSince1970)
            let m = Int(secs) / 60
            if m > 60 { return "\(m / 60)h \(m % 60)m left" }
            return "\(m) min left"
        }()

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: .dsShieldBg,
            icon: UIImage(systemName: "target"),
            title: ShieldConfiguration.Label(
                text: "You're in focus mode.",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: remaining.isEmpty
                    ? "Go back to \(focusApp)."
                    : "\(remaining). Go back to \(focusApp).",
                color: .dsTextSecondary
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Back to \(focusApp)",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(hex: "1E3A28"),   // DS shield-commit green
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "End focus session",
                color: .dsTextSecondary
            )
        )
    }

    // MARK: - Usage data

    private func fetchTodaySeconds(tokenString: String) -> TimeInterval {
        SharedDefaults.store.double(forKey: "todaySeconds_\(tokenString)")
    }
}
