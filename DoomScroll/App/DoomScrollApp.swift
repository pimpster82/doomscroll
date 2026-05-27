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
    }
}

@MainActor
class AuthorizationManager: ObservableObject {
    @Published var isAuthorized = false

    init() {
        checkAuthorization()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    private func checkAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }
}
