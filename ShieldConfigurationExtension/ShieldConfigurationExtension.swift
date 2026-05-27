import ManagedSettings
import ManagedSettingsUI
import UIKit
import Foundation

// Renders the shield overlay UI for each conversation step.
// Called by the OS whenever the shield needs to display or refresh (after .defer).
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let tokenString = application.token?.description ?? ""
        let state = ShieldConversationState.load(for: tokenString)
        let profile = UserProfile.load()
        let appName = application.localizedDisplayName ?? "this app"
        let overridesLeft = OverrideTracker.remainingToday(for: tokenString)

        return configuration(
            step: state.step,
            appName: appName,
            profile: profile,
            overridesLeft: overridesLeft,
            tokenString: tokenString
        )
    }

    override func configuration(shielding application: Application, in context: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            title: ShieldConfiguration.Label(text: "Take a breath.", color: .white)
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
        case .impact:
            return impactScreen(appName: appName, profile: profile, overridesLeft: overridesLeft, tokenString: tokenString)
        case .reflection:
            return reflectionScreen(appName: appName, profile: profile)
        case .commit:
            return commitScreen(appName: appName, overridesLeft: overridesLeft)
        }
    }

    // Step 1: Show today's usage and a near-term relational stake.
    private func impactScreen(appName: String, profile: UserProfile?, overridesLeft: Int, tokenString: String) -> ShieldConfiguration {
        let todaySeconds = fetchTodaySeconds(tokenString: tokenString)
        let minutes = max(0, Int(todaySeconds / 60))

        let stake: String
        if let profile {
            let calculator = LifetimeImpactCalculator(profile: profile)
            stake = calculator.appImpact(appName: appName, todaySeconds: todaySeconds, weeklyTotalSeconds: todaySeconds * 5).relationalStake
        } else {
            stake = minutes > 0 ? "You've spent \(minutes) min on \(appName) today." : "Pausing before you open \(appName)."
        }

        let overrideLabel = overridesLeft == 2 ? "Open it anyway" :
                            overridesLeft == 1 ? "Open it (last override today)" :
                            "No overrides left today"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: stake, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "\(overridesLeft) override\(overridesLeft == 1 ? "" : "s") left today",
                color: UIColor.systemGray2
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: overridesLeft > 0 ? "Keep going →" : "Stay blocked",
                color: overridesLeft > 0 ? .white : UIColor.systemGray
            ),
            primaryButtonBackgroundColor: overridesLeft > 0 ? UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1) : UIColor.systemGray5,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Not right now", color: UIColor.systemGray2)
        )
    }

    // Step 2: Age/gender-adapted reflective question.
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
            backgroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1),
            icon: UIImage(systemName: "bubble.left"),
            title: ShieldConfiguration.Label(text: prompt.question, color: .white),
            subtitle: ShieldConfiguration.Label(text: prompt.hint, color: UIColor.systemGray2),
            primaryButtonLabel: ShieldConfiguration.Label(text: prompt.continueLabel, color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Actually, never mind", color: UIColor.systemGray2)
        )
    }

    // Step 3: Commit to a session time limit.
    private func commitScreen(appName: String, overridesLeft: Int) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1),
            icon: UIImage(systemName: "timer"),
            title: ShieldConfiguration.Label(
                text: "Set your limit for this session.",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                // The actual time picker lives in the main app; the shield approximates
                // this by opening 15-min sessions. A deeper integration requires
                // the workaround notification tap -> main app -> return flow.
                text: "15 minutes, then \(appName) locks again. You'll have \(max(0, overridesLeft - 1)) override\(overridesLeft - 1 == 1 ? "" : "s") left today.",
                color: UIColor.systemGray2
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start 15-min session", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.15, green: 0.35, blue: 0.15, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay closed", color: UIColor.systemGray2)
        )
    }

    // MARK: - Usage data

    private func fetchTodaySeconds(tokenString: String) -> TimeInterval {
        // DeviceActivity data is fetched by the monitor extension and stored in shared defaults.
        let key = "todaySeconds_" + tokenString
        return SharedDefaults.store.double(forKey: key)
    }
}
