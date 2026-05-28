import SwiftUI
import FamilyControls

@main
struct DoomScrollApp: App {
    @StateObject private var authManager = AuthorizationManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var focusManager = FocusModeManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthorized {
                    if UserProfile.load() == nil || !authManager.hasCompletedOnboarding {
                        OnboardingView()
                            .environmentObject(authManager)
                            .environmentObject(subscriptionManager)
                    } else {
                        DashboardView()
                            .environmentObject(authManager)
                            .environmentObject(subscriptionManager)
                            .environmentObject(focusManager)
                    }
                } else {
                    AuthorizationView()
                        .environmentObject(authManager)
                }
            }
            // Single injection point for the mascot. Swap activeMascot to change
            // the character or add a seasonal overlay globally.
            .mascot(activeMascot)
        }
        // All DS colors are fixed hex values with no dark-adaptive variants.
        // Force light mode until dark-adaptive Color tokens are added to DesignSystem.
        .preferredColorScheme(.light)
    }

    // Persisted in the App Group store so extensions can read it if needed.
    // Defaults true (seasonal layer on).
    @AppStorage(SharedDefaults.Key.seasonalFitEnabled, store: SharedDefaults.store)
    private var seasonalFitEnabled = true

    private var activeMascot: any MascotStyle {
        // Switch to RiveMascot once square_eyes.riv is in the bundle:
        // return RiveMascot(fileName: "square_eyes",
        //                   season: SeasonalTheme.current,
        //                   seasonEnabled: seasonalFitEnabled)
        return SquareEyesMascot()
    }
}

@MainActor
class AuthorizationManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String? = nil
    @Published var hasCompletedOnboarding: Bool

    init() {
        hasCompletedOnboarding = SharedDefaults.store.bool(forKey: SharedDefaults.Key.hasCompletedOnboarding)
        checkAuthorization()
    }

    func requestAuthorization() async {
        authorizationError = nil
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
            authorizationError = "Screen Time permission was denied. Go to Settings → Screen Time to enable it for DoomScroll."
        }
    }

    func markOnboardingComplete() {
        SharedDefaults.store.set(true, forKey: SharedDefaults.Key.hasCompletedOnboarding)
        hasCompletedOnboarding = true
    }

    private func checkAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }
}
