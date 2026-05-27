import SwiftUI
import DeviceActivity
import FamilyControls

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthorizationManager
    @State private var impact: LifetimeImpact?
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showLifetimeStats = false

    private var profile: UserProfile? { UserProfile.load() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        relationalStakeCard
                        overrideStatusRow
                        if showLifetimeStats { lifetimeCard }
                        managedAppsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("DoomScroll")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.white)
                    }
                }
            }
            .onAppear { loadImpact() }
        }
        .preferredColorScheme(.dark)
    }

    // Primary card: near-term relational stake — this is what users see first.
    private var relationalStakeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Button {
                    withAnimation { showLifetimeStats.toggle() }
                } label: {
                    Text(showLifetimeStats ? "Hide lifetime" : "See lifetime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let impact {
                Text(impact.relationalStake)
                    .font(.title3.weight(.medium))
                    .lineSpacing(4)

                Divider().overlay(Color.white.opacity(0.1))

                HStack(spacing: 20) {
                    statPill(label: "Daily avg", value: impact.dailyAverageSeconds.durationString)
                }
            } else {
                Text("Building your picture...")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    // Secondary card: lifetime numbers. Hidden by default, revealed on tap.
    private var lifetimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime projection")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            if let impact {
                HStack(spacing: 20) {
                    statPill(label: "At this rate", value: String(format: "%.1f yrs", impact.yearsAtCurrentRate))
                    statPill(label: "Recoverable at −50%", value: String(format: "%.1f yrs", impact.yearsRecoverableAt50Percent))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Based on \(Int(impact.dailyAverageSeconds / 3600 * 10) / 10)h daily average over the past year.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var overrideStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("2 overrides per app per day")
                    .font(.callout)
                Text("Each override starts a conversation.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var managedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Managed apps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Button {
                    showAppPicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                }
                .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
                .onChange(of: selection) { _, newValue in
                    AppBlocker.apply(selection: newValue)
                }
            }

            Text("Tap the shield on any managed app to start a conversation.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadImpact() {
        guard let profile else { return }
        // In a real build, fetch 365-day total from DeviceActivity report.
        // Using a 3h/day placeholder until DeviceActivity data is wired in.
        let estimatedAnnualSeconds: TimeInterval = 3 * 3600 * 365
        impact = LifetimeImpactCalculator(profile: profile).calculate(totalSecondsLastYear: estimatedAnnualSeconds)
    }
}
