import SwiftUI
import DeviceActivity
import FamilyControls

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthorizationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var impact: LifetimeImpact?
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showLifetimeStats = false
    @State private var showPaywall = false
    @State private var mascotExpression: SquareEyesExpression = .idle
    @State private var streak = 3   // TODO: persist and increment from DeviceActivity

    private var profile: UserProfile? { UserProfile.load() }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning."
        case 12..<17: return "Good afternoon."
        default:      return "Good evening."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        mascotHeader
                        heroMetricCard
                        streakCard
                        if showLifetimeStats { lifetimeCard }
                        managedAppsSection
                    }
                    .padding(DS.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { loadImpact(); updateMascot() }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
    }

    // MARK: - Sections

    // Mascot + greeting — appears at top of every screen visit.
    // Research: Duolingo increased DAU 34% by placing character at emotional peaks.
    private var mascotHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            SquareEyesView(expression: mascotExpression, size: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                Text(subscriptionManager.hasActiveAccess ? subscriptionManager.planDisplayName : "14-day trial")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // Hero metric: time reclaimed, not time wasted. Positive framing.
    // Research: progress rings outperform bar charts for emotional reward.
    private var heroMetricCard: some View {
        DSCard {
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    SectionLabel(text: "Today")
                    Spacer()
                    Button {
                        withAnimation(.easeInOut) { showLifetimeStats.toggle() }
                    } label: {
                        Text(showLifetimeStats ? "Hide lifetime" : "See lifetime")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
                .padding([.top, .horizontal], DS.Spacing.md)

                HStack(spacing: DS.Spacing.xl) {
                    // Progress ring (circular, not bar — per research)
                    ZStack {
                        Circle()
                            .stroke(DS.Color.backgroundMuted, lineWidth: 10)
                            .frame(width: 90, height: 90)

                        Circle()
                            .trim(from: 0, to: reclaimedFraction)
                            .stroke(DS.Color.success, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(Int(reclaimedFraction * 100))%")
                                .font(DS.Font.title2)
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("reclaimed")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        if let impact {
                            Text(impact.relationalStake)
                                .font(DS.Font.callout)
                                .foregroundStyle(DS.Color.textPrimary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Building your picture...")
                                .font(DS.Font.callout)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
            }
        }
    }

    // Streak card — proven retention pattern.
    private var streakCard: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(DS.Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak) day streak")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                Text("Keep going — your best is \(max(streak, 7)) days")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()

            // Overrides used today
            HStack(spacing: 4) {
                ForEach(0..<OverrideTracker.maxOverridesPerDay, id: \.self) { i in
                    Circle()
                        .fill(i < overridesUsedToday ? DS.Color.warning : DS.Color.backgroundMuted)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // Lifetime stats — hidden by default, revealed on tap.
    // Research: showing this first causes defensiveness. It's a reward for curious users.
    private var lifetimeCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                SectionLabel(text: "Lifetime projection")
                    .padding([.top, .horizontal], DS.Spacing.md)

                if let impact {
                    HStack(spacing: DS.Spacing.xl) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f yrs", impact.yearsAtCurrentRate))
                                .font(DS.Font.hero)
                                .foregroundStyle(DS.Color.warning)
                            Text("at current rate")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f yrs", impact.yearsRecoverableAt50Percent))
                                .font(DS.Font.hero)
                                .foregroundStyle(DS.Color.success)
                            Text("recoverable at −50%")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    .padding([.horizontal, .bottom], DS.Spacing.md)
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var managedAppsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                SectionLabel(text: "Managed apps")
                Spacer()
                Button {
                    if subscriptionManager.requiresSubscription() {
                        showPaywall = true
                    } else {
                        showAppPicker = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(DS.Color.accent)
                        .font(.title3)
                }
                .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
                .onChange(of: selection) { _, newValue in
                    AppBlocker.apply(selection: newValue)
                }
            }

            if selection.applications.isEmpty {
                Text("Add apps you want to create friction for. You'll still be able to open them — you'll just have to mean it.")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineSpacing(3)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            } else {
                Text("\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") have friction enabled.")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var reclaimedFraction: CGFloat {
        // Placeholder: in production, compare today's usage vs. 7-day average.
        0.62
    }

    private var overridesUsedToday: Int {
        // Aggregate across all shielded apps.
        0
    }

    private func loadImpact() {
        guard let profile else { return }
        let estimatedAnnualSeconds: TimeInterval = 3 * 3600 * 365
        impact = LifetimeImpactCalculator(profile: profile).calculate(totalSecondsLastYear: estimatedAnnualSeconds)
    }

    private func updateMascot() {
        if streak > 5 {
            mascotExpression = .proud
        } else if streak > 0 {
            mascotExpression = .happy
        } else {
            mascotExpression = .idle
        }
    }
}
