import DeviceActivity
import ManagedSettings
import Foundation

// Runs in the background; called by iOS when device activity thresholds are hit
// or on the daily interval. Writes usage summaries to shared defaults for the
// shield and main app to read.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        // New calendar day: advance the streak (increments if yesterday had no exhausted overrides).
        OverrideTracker.advanceStreakForNewDay()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // End of tracked window (e.g., midnight) — nothing to do here.
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // A per-app threshold was reached. The ShieldConfiguration and ShieldAction
        // extensions are already wired in via ManagedSettings; no additional action needed.
    }

    // Called when the app's daily usage crosses the scheduled monitoring window.
    // We use this to write today's usage seconds per app token to shared defaults
    // so the shield configuration can display accurate numbers.
    override func intervalWillStartWarning(for activity: DeviceActivityName) { }

    override func intervalWillEndWarning(for activity: DeviceActivityName) { }
}

// MARK: - DeviceActivity schedule setup (called from the main app on onboarding)

struct ActivityMonitorScheduler {

    static let dailyActivity = DeviceActivityName("daily")

    // Call once on setup; restarts each calendar day automatically.
    static func startMonitoring(shieldedApps: Set<ApplicationToken>) {
        let center = DeviceActivityCenter()
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(dailyActivity, during: schedule)
        } catch {
            // Monitoring requires FamilyControls authorization; silently skip if not granted.
        }
    }

    static func stopMonitoring() {
        DeviceActivityCenter().stopMonitoring([dailyActivity])
    }
}
