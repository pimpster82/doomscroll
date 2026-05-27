import ManagedSettings
import FamilyControls

// Applies or removes shields for the selected apps.
// Must be called from the main app (not extensions) as it writes to ManagedSettingsStore.
struct AppBlocker {
    private static let store = ManagedSettingsStore()

    static func apply(selection: FamilyActivitySelection) {
        store.shield.applications = selection.applications.isEmpty ? nil : selection.applications
    }

    static func removeAll() {
        store.shield.applications = nil
    }

    // Temporarily remove a shield for a specific app (after override commit).
    // The DeviceActivityMonitor re-applies it after the session budget expires.
    static func temporarilyUnshield(token: ApplicationToken) {
        var current = store.shield.applications ?? []
        current.remove(token)
        store.shield.applications = current.isEmpty ? nil : current
    }

    // Re-shield a specific app after its session budget expires.
    static func reshield(token: ApplicationToken) {
        var current = store.shield.applications ?? []
        current.insert(token)
        store.shield.applications = current
    }
}
