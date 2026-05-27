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

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

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
        .foregroundStyle(.white)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i <= step ? Color.white : Color.white.opacity(0.2))
                    .frame(height: 3)
                    .animation(.easeInOut, value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Spacer()
            Text("Your time is the only thing you can't get more of.")
                .font(.largeTitle.weight(.bold))
                .lineSpacing(4)

            Text("DoomScroll helps you scroll less — not by blocking you, but by making sure you actually chose to open that app.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            Spacer()

            Button("Let's go") { step = 1 }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Text("A bit about you")
                .font(.title.weight(.bold))

            Text("This stays on your device. It helps DoomScroll speak to you like a person, not an app.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                label("Birth year")
                Picker("Birth year", selection: $birthYear) {
                    ForEach((1940...currentYear - 10).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                label("Gender")
                Picker("Gender", selection: $gender) {
                    ForEach(UserProfile.Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .pickerStyle(.segmented)

                label("Life expectancy (years)")
                HStack {
                    Slider(value: Binding(
                        get: { Double(lifeExpectancy) },
                        set: { lifeExpectancy = Int($0) }
                    ), in: 60...100, step: 1)
                    Text("\(lifeExpectancy)")
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }

            Spacer()

            Button("Continue") { step = 2 }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var appPickerStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Text("Which apps do you want to slow down?")
                .font(.title.weight(.bold))

            Text("These will get the friction treatment — you can still open them, but you'll have to mean it.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showAppPicker = true
            } label: {
                HStack {
                    Image(systemName: "apps.iphone")
                    Text(selection.applications.isEmpty ? "Choose apps" : "\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") selected")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)

            Spacer()

            Button("Continue") { step = 3 }
                .disabled(selection.applications.isEmpty)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Text("You're set up.")
                .font(.title.weight(.bold))

            let age = currentYear - birthYear
            let yearsLeft = max(0, lifeExpectancy - age)

            VStack(alignment: .leading, spacing: 12) {
                impactRow(icon: "clock", text: "~\(yearsLeft) years of screen time ahead")
                impactRow(icon: "hand.raised", text: "2 override conversations per app per day")
                impactRow(icon: "lock.shield", text: "\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") will have friction")
            }
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            Button("Start") { finishOnboarding() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private func impactRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
    }

    private func finishOnboarding() {
        let profile = UserProfile(birthYear: birthYear, gender: gender, lifeExpectancy: lifeExpectancy)
        profile.save()

        // Apply shields via ManagedSettings.
        AppBlocker.apply(selection: selection)
        ActivityMonitorScheduler.startMonitoring(shieldedApps: selection.applications)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.white : Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(isEnabled ? Color(red: 0.05, green: 0.05, blue: 0.1) : .gray)
            .font(.body.weight(.semibold))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
