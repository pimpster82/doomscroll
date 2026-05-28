import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var profile = UserProfile.load() ?? UserProfile(birthYear: 1990, gender: .preferNotToSay)
    @State private var saved = false
    @State private var showPaywall = false

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            List {
                profileSection
                subscriptionSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if saved {
                Text("Saved")
                    .font(DS.Font.callout)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .animation(.easeInOut, value: saved)
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            Picker("Birth year", selection: $profile.birthYear) {
                ForEach((1940...currentYear - 10).reversed(), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .foregroundStyle(DS.Color.textPrimary)

            Picker("Gender", selection: $profile.gender) {
                ForEach(UserProfile.Gender.allCases, id: \.self) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .foregroundStyle(DS.Color.textPrimary)

            Stepper(
                "Life expectancy: \(profile.lifeExpectancy) yrs",
                value: $profile.lifeExpectancy, in: 60...100
            )
            .foregroundStyle(DS.Color.textPrimary)

            Button("Save profile") {
                profile.save()
                withAnimation { saved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
            }
            .foregroundStyle(DS.Color.accent)
        } header: {
            SectionLabel(text: "Your profile")
        }
    }

    private var subscriptionSection: some View {
        Section {
            HStack {
                Text("Plan")
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Text(subscriptionManager.planDisplayName)
                    .foregroundStyle(DS.Color.textSecondary)
                    .font(DS.Font.callout)
            }

            if subscriptionManager.isFamilyBeneficiary {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(DS.Color.teal)
                    Text("Shared by a family member")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            if !subscriptionManager.hasActiveAccess {
                Button("Upgrade to premium") { showPaywall = true }
                    .foregroundStyle(DS.Color.accent)
            }

            Button("Restore purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .foregroundStyle(DS.Color.textSecondary)
        } header: {
            SectionLabel(text: "Subscription")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "1.0")
                .foregroundStyle(DS.Color.textPrimary)
            Link("Privacy Policy",
                 destination: URL(string: "https://pimpster82.github.io/doomscroll/privacy-policy")!)
                .foregroundStyle(DS.Color.accent)
        } header: {
            SectionLabel(text: "About")
        }
    }
}
