import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthorizationManager
    @State private var birthYear = Calendar.current.component(.year, from: Date()) - 30
    @State private var gender: UserProfile.Gender = .preferNotToSay
    @State private var lifeExpectancy = 82
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var step = 0
    @State private var mascotExpression: SquareEyesExpression = .idle
    @State private var showPaywall = false

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    profileStep.tag(1)
                    appPickerStep.tag(2)
                    summaryStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i <= step ? DS.Color.accent : DS.Color.backgroundMuted)
                    .frame(height: 4)
                    .animation(.easeInOut, value: step)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Spacer()

            HStack {
                Spacer()
                SquareEyesView(expression: .concerned, size: 110)
                Spacer()
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("My eyes got this way from too much screen time.")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineSpacing(4)

                Text("Let's make sure yours don't.")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.accent)
                    .lineSpacing(4)
            }

            Text("DoomScroll creates friction before you open time-sink apps — not a hard block, just a moment to make sure you actually mean it.")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(4)

            Spacer()

            DSPrimaryButton(label: "Let's go") { advance(to: 1, mascot: .idle) }
        }
        .padding(DS.Spacing.xl)
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Spacer()

            mascotRow(expression: mascotExpression,
                      text: "This stays on your device. It helps me speak to you like a person, not an app.")

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                formLabel("Birth year")
                Picker("Birth year", selection: $birthYear) {
                    ForEach((1940...currentYear - 10).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .background(DS.Color.backgroundMuted, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                formLabel("Gender")
                Picker("Gender", selection: $gender) {
                    ForEach(UserProfile.Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .tint(DS.Color.accent)

                formLabel("Life expectancy (years)")
                HStack {
                    Slider(value: Binding(
                        get: { Double(lifeExpectancy) },
                        set: { lifeExpectancy = Int($0) }
                    ), in: 60...100, step: 1)
                    .tint(DS.Color.accent)
                    Text("\(lifeExpectancy)")
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textPrimary)
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }

            Spacer()

            DSPrimaryButton(label: "Continue") { advance(to: 2, mascot: .happy) }
        }
        .padding(DS.Spacing.xl)
    }

    private var appPickerStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Spacer()

            mascotRow(expression: .idle,
                      text: "Which apps do you want to slow down? You can still open them — you'll just have to mean it.")

            Button {
                showAppPicker = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "apps.iphone")
                        .foregroundStyle(DS.Color.accent)
                    Text(selection.applications.isEmpty
                         ? "Choose apps"
                         : "\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") selected")
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DS.Color.textTertiary)
                        .font(DS.Font.caption)
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)

            Spacer()

            DSPrimaryButton(label: "Continue", disabled: selection.applications.isEmpty) {
                advance(to: 3, mascot: .happy)
            }
        }
        .padding(DS.Spacing.xl)
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Spacer()

            HStack {
                Spacer()
                SquareEyesView(expression: .proud, size: 100)
                Spacer()
            }

            Text("You're set up.")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.textPrimary)

            let age = currentYear - birthYear
            let yearsLeft = max(0, lifeExpectancy - age)

            VStack(spacing: DS.Spacing.sm) {
                summaryRow(icon: "hourglass", text: "~\(yearsLeft) years of screen time ahead to reclaim")
                summaryRow(icon: "hand.raised",  text: "2 override conversations per app per day")
                summaryRow(icon: "lock.shield",  text: "\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") with friction enabled")
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)

            Spacer()

            DSPrimaryButton(label: "Start my 14-day trial") { finishOnboarding() }
        }
        .padding(DS.Spacing.xl)
        .sheet(isPresented: $showPaywall, onDismiss: { authManager.markOnboardingComplete() }) {
            NavigationStack { PaywallView() }
        }
    }

    // MARK: - Components

    private func mascotRow(expression: SquareEyesExpression, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            SquareEyesView(expression: expression, size: 56)
            Text(text)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(DS.Color.accent)
                .frame(width: 20)
            Text(text)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.textPrimary)
        }
    }

    private func formLabel(_ text: String) -> some View {
        SectionLabel(text: text)
    }

    // MARK: - Actions

    private func advance(to newStep: Int, mascot: SquareEyesExpression) {
        withAnimation {
            step = newStep
            mascotExpression = mascot
        }
    }

    private func finishOnboarding() {
        let profile = UserProfile(birthYear: birthYear, gender: gender, lifeExpectancy: lifeExpectancy)
        profile.save()
        AppBlocker.apply(selection: selection)
        ActivityMonitorScheduler.startMonitoring(shieldedApps: selection.applications)
        showPaywall = true
    }
}

// MARK: - Shared button style

struct DSPrimaryButton: View {
    let label: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    disabled ? DS.Color.backgroundMuted : DS.Color.accent,
                    in: RoundedRectangle(cornerRadius: DS.Radius.md)
                )
                .foregroundStyle(disabled ? DS.Color.textTertiary : .white)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}
