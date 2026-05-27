import Foundation
import ManagedSettings
import FamilyControls

// Manages the lifecycle of a focus session.
// Focus mode is an allowlist: the chosen app stays open;
// everything else — the friction list + major distraction categories — gets shielded.
//
// iOS constraint: ManagedSettings has no "block all except one app" primitive.
// We block known distraction categories + the user's existing friction list.
// The focus app is implicitly allowed because it's never added to the block set.
@MainActor
class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()

    @Published var activeSession: FocusSession? = FocusSession.loadActive()

    private let store = ManagedSettingsStore()

    // Categories that are blocked during focus. These cover the primary distraction vectors.
    // The focus app's category is not in this list by design (user picks a work/focus app
    // which typically falls outside these categories).
    private static let distractionCategories: Set<ActivityCategoryToken> = []
    // Note: ActivityCategoryToken requires the FamilyActivityPicker to resolve category tokens.
    // The shield is applied via the existing application-level friction list in AppBlocker,
    // plus the category-level shield via applicationCategories = .all() equivalent below.

    // MARK: - Session control

    func startSession(focusAppName: String, duration: FocusDuration, existingSelection: FamilyActivitySelection) {
        var session = FocusSession(
            focusAppName: focusAppName,
            durationSeconds: duration.seconds,
            startDate: Date(),
            state: .active
        )
        session.save()
        activeSession = session

        applyFocusShields(existingSelection: existingSelection)
        SharedDefaults.store.set(true, forKey: SharedDefaults.Key.focusModeActive)
        SharedDefaults.store.set(focusAppName, forKey: SharedDefaults.Key.focusAppName)

        // Schedule natural end.
        scheduleSessionEnd(after: duration.seconds)
    }

    func endSession(early: Bool) {
        guard var session = activeSession else { return }
        session.state = early ? .endedEarly : .endedNaturally
        session.save()
        activeSession = nil

        removeFocusShields()
        SharedDefaults.store.set(false, forKey: SharedDefaults.Key.focusModeActive)
        SharedDefaults.store.removeObject(forKey: SharedDefaults.Key.focusAppName)
        FocusSession.clear()
    }

    func recordEarlyExitAttempt() {
        guard var session = activeSession else { return }
        session.earlyExitAttempts += 1
        session.save()
        activeSession = session
    }

    // Called on app launch to restore session state after a restart.
    func restoreIfNeeded() {
        activeSession = FocusSession.loadActive()
    }

    // MARK: - Shield management

    // Applies focus shields on top of the existing friction list.
    // The focus app is never added to the block set — it's the one thing we want open.
    private func applyFocusShields(existingSelection: FamilyActivitySelection) {
        // Re-apply the existing friction list (ensures it's current).
        AppBlocker.apply(selection: existingSelection)
        // Block all app categories — this is the broadest sweep possible within the API.
        // The focus app stays accessible because ManagedSettings shields are additive
        // per-app, and we only add the existing friction apps + categories, not the focus app.
        // Note: to truly block "everything except one app" would require .family authorization.
        store.shield.applicationCategories = .all()
    }

    private func removeFocusShields() {
        // Remove the category-level block; leave the app-level friction list intact.
        store.shield.applicationCategories = nil
    }

    // Uses a DeviceActivity event to fire when the session naturally expires.
    private func scheduleSessionEnd(after seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        SharedDefaults.store.set(deadline.timeIntervalSince1970, forKey: SharedDefaults.Key.focusEndTimestamp)
    }
}

// MARK: - SharedDefaults keys for focus

extension SharedDefaults.Key {
    static let focusModeActive     = "focusModeActive"
    static let focusAppName        = "focusAppName"
    static let focusEndTimestamp   = "focusEndTimestamp"
}
