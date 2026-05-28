import SwiftUI
import DeviceActivity
import FamilyControls

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthorizationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var focusManager: FocusModeManager
    @State private var impact: LifetimeImpact?
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showLifetimeStats = false
    @State private var showPaywall = false
    @State private var showFocusMode = false
    @State private var mascotMood: MascotMood = .idle
    @State private var streak = 0
    @State private var bestStreak = 0

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
                        // Active focus session sits at the top when running.
                        if focusManager.activeSession != nil {
                            ActiveFocusView()
                        }
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
            .onAppear {
                loadImpact(); loadStreak(); updateMascot(); pushWidgetSnapshot()
                NotificationScheduler.requestPermissionIfNeeded()
                NotificationScheduler.scheduleDailyCheckIn(streak: streak)
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
        .sheet(isPresented: $showFocusMode) {
            NavigationStack {
                FocusModeView(existingSelection: selection)
                    .environmentObject(focusManager)
            }
        }
    }

    // MARK: - Sections

    // Mascot + greeting — appears at top of every screen visit.
    // Research: Duolingo increased DAU 34% by placing character at emotional peaks.
    private var mascotHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            MascotView(mood: mascotMood, size: 64)

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
                .font(DS.Font.title2)
                .foregroundStyle(DS.Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak) day streak")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                Text(bestStreak > streak
                 ? "Your best: \(bestStreak) days — keep going"
                 : streak > 0 ? "Personal best — keep it up!" : "Start your streak today")
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
                    // ViewThatFits picks HStack on wide screens (iPhone 14+) and
                    // falls back to VStack on narrow screens (iPhone SE, 375 pt).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: DS.Spacing.xl) {
                            lifetimeStat(value: impact.yearsAtCurrentRate,
                                         label: "at current rate",
                                         color: DS.Color.warning)
                            lifetimeStat(value: impact.yearsRecoverableAt50Percent,
                                         label: "recoverable at −50%",
                                         color: DS.Color.success)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            lifetimeStat(value: impact.yearsAtCurrentRate,
                                         label: "at current rate",
                                         color: DS.Color.warning)
                            lifetimeStat(value: impact.yearsRecoverableAt50Percent,
                                         label: "recoverable at −50%",
                                         color: DS.Color.success)
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
                        .font(DS.Font.title2)
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
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if focusManager.activeSession == nil {
                    showFocusMode = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: focusManager.activeSession != nil ? "target" : "target")
                        .foregroundStyle(focusManager.activeSession != nil ? DS.Color.success : DS.Color.teal)
                    Text(focusManager.activeSession != nil ? "Focusing" : "Focus")
                        .font(DS.Font.callout)
                        .foregroundStyle(focusManager.activeSession != nil ? DS.Color.success : DS.Color.teal)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: SettingsView().environmentObject(subscriptionManager)) {
                Image(systemName: "gearshape")
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func lifetimeStat(value: Double, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%.1f yrs", value))
                .font(DS.Font.hero)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var reclaimedFraction: CGFloat {
        // Placeholder until DeviceActivity usage tracking is implemented (TODO #25).
        0.62
    }

    private var overridesUsedToday: Int {
        OverrideTracker.totalOverridesToday()
    }

    private func loadImpact() {
        guard let profile else { return }
        let estimatedAnnualSeconds: TimeInterval = 3 * 3600 * 365
        impact = LifetimeImpactCalculator(profile: profile).calculate(totalSecondsLastYear: estimatedAnnualSeconds)
    }

    private func loadStreak() {
        streak = OverrideTracker.currentStreak()
        bestStreak = OverrideTracker.bestStreak()
        NotificationScheduler.scheduleStreakMilestoneIfNeeded(streak: streak)
        if streak == 0 { NotificationScheduler.cancelDailyCheckIn() }
    }

    private func pushWidgetSnapshot() {
        let totalManaged = 2  // Each managed app gets maxOverridesPerDay; placeholder until token list is accessible
        let overridesLeft = max(0, OverrideTracker.maxOverridesPerDay * totalManaged - OverrideTracker.totalOverridesToday())
        SharedDefaults.updateWidgetSnapshot(
            streak: streak,
            reclaimedPercent: Int(reclaimedFraction * 100),
            overridesLeft: overridesLeft
        )
    }

    private func updateMascot() {
        if streak > 5 {
            mascotMood = .proud
        } else if streak > 0 {
            mascotMood = .happy
        } else {
            mascotMood = .idle
        }
    }
}
