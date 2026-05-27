import SwiftUI
import FamilyControls

@main
struct DoomScrollApp: App {
    @StateObject private var authManager = AuthorizationManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var focusManager = FocusModeManager.shared

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthorized {
                if UserProfile.load() == nil {
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
        // All DS colors are fixed hex values with no dark-adaptive variants.
        // Force light mode until dark-adaptive Color tokens are added to DesignSystem.
        .preferredColorScheme(.light)
    }
}

@MainActor
class AuthorizationManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String? = nil

    init() {
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

    private func checkAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }
}
