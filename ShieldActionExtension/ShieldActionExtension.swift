import ManagedSettings
import Foundation

// The Shield Action extension handles taps on the two buttons of the shield overlay.
// Because ShieldActionResponse cannot open the main app (Apple API limitation),
// the entire conversation happens here by cycling through .defer states.
//
// Flow: impact -> reflection -> commit -> (app opens or stays blocked)
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let tokenString = application.description
        var state = ShieldConversationState.load(for: tokenString)

        switch action {
        case .primaryButtonPressed:
            handlePrimary(state: &state, tokenString: tokenString, completionHandler: completionHandler)
        case .secondaryButtonPressed:
            // Secondary is always "Not right now" / close.
            resetState(tokenString: tokenString)
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    // MARK: - State machine

    private func handlePrimary(state: inout ShieldConversationState, tokenString: String, completionHandler: (ShieldActionResponse) -> Void) {
        switch state.step {
        case .impact:
            // User acknowledged the impact screen — move to reflection.
            guard OverrideTracker.canOverride(for: tokenString) else {
                // No overrides left today; keep blocked.
                resetState(tokenString: tokenString)
                completionHandler(.defer)
                return
            }
            state.step = .reflection
            state.save(for: tokenString)
            completionHandler(.defer)

        case .reflection:
            // User answered (or skipped) the reflection — move to commit.
            state.step = .commit
            state.save(for: tokenString)
            completionHandler(.defer)

        case .commit:
            // User has set their time limit and confirmed. Record override and open.
            OverrideTracker.recordOverride(for: tokenString)
            scheduleBudgetReblock(tokenString: tokenString, seconds: state.sessionBudgetSeconds)
            resetState(tokenString: tokenString)
            completionHandler(.none)    // .none = allow the app to open
        }
    }

    // Resets conversation state so next time starts fresh.
    private func resetState(tokenString: String) {
        ShieldConversationState().save(for: tokenString)
    }

    // Schedules a DeviceActivity event that will re-shield the app after the chosen budget.
    private func scheduleBudgetReblock(tokenString: String, seconds: TimeInterval) {
        guard seconds > 0 else { return }
        let key = SharedDefaults.Key.dailyBudgets + tokenString
        SharedDefaults.store.set(seconds, forKey: key)
        SharedDefaults.store.set(Date().addingTimeInterval(seconds), forKey: key + "_deadline")
    }
}
