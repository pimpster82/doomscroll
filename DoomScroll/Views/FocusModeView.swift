import SwiftUI
import FamilyControls

// Entry point for starting a focus session.
// User picks what they want to focus ON (the one allowed app),
// sets a duration, and the rest gets locked down.
struct FocusModeView: View {
    @EnvironmentObject var focusManager: FocusModeManager
    @Environment(\.dismiss) private var dismiss

    @State private var focusAppName = ""
    @State private var showAppPicker = false
    @State private var focusSelection = FamilyActivitySelection()
    @State private var selectedDuration: FocusDuration = .standard
    @State private var customMinutes: Double = 30
    @State private var showCustomPicker = false
    @State private var mascotExpression: SquareEyesExpression = .idle

    // The user's existing managed app selection (friction list) is passed in
    // so FocusModeManager can re-apply it during focus.
    var existingSelection: FamilyActivitySelection

    private var canStart: Bool { !focusAppName.isEmpty }

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    mascotIntro
                    focusAppPicker
                    durationPicker
                    dndReminder
                    if canStart { startButton }
                }
                .padding(DS.Spacing.lg)
            }
        }
        .navigationTitle("Focus Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var mascotIntro: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            SquareEyesView(expression: mascotExpression, size: 64)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Choose one thing to work on.")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                Text("Everything else gets blocked. You can end early, but you'll have to explain yourself.")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var focusAppPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(text: "What are you focusing on?")

            Button {
                showAppPicker = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(focusAppName.isEmpty ? DS.Color.textTertiary : DS.Color.success)
                        .font(.title3)
                    Text(focusAppName.isEmpty ? "Pick the app you'll work in" : focusAppName)
                        .font(DS.Font.headline)
                        .foregroundStyle(focusAppName.isEmpty ? DS.Color.textTertiary : DS.Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DS.Color.textTertiary)
                        .font(DS.Font.caption)
                }
                .padding(DS.Spacing.md)
                .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $focusSelection
            )
            .onChange(of: focusSelection) { _, newValue in
                focusAppName = newValue.applications.first.map { _ in "Selected app" } ?? ""
                withAnimation { mascotExpression = focusAppName.isEmpty ? .idle : .happy }
            }

            if !focusAppName.isEmpty {
                Text("All other apps — including your friction list and major distraction categories — will be blocked for the duration.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineSpacing(3)
            }
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(text: "How long?")

            HStack(spacing: DS.Spacing.sm) {
                ForEach(FocusDuration.allCases, id: \.label) { duration in
                    durationChip(duration)
                }
                customChip
            }
        }
    }

    private func durationChip(_ duration: FocusDuration) -> some View {
        Button {
            withAnimation { selectedDuration = duration; showCustomPicker = false }
        } label: {
            Text(duration.label)
                .font(DS.Font.callout)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.full)
                        .fill(isSelected(duration) ? DS.Color.accent : DS.Color.backgroundMuted)
                )
                .foregroundStyle(isSelected(duration) ? .white : DS.Color.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var customChip: some View {
        Button {
            withAnimation { showCustomPicker.toggle() }
        } label: {
            Text(customLabel)
                .font(DS.Font.callout)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.full)
                        .fill(showCustomPicker ? DS.Color.teal : DS.Color.backgroundMuted)
                )
                .foregroundStyle(showCustomPicker ? .white : DS.Color.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var customLabel: String {
        if case .custom = selectedDuration {
            return "\(Int(customMinutes)) min"
        }
        return "Custom"
    }

    private func isSelected(_ duration: FocusDuration) -> Bool {
        switch (selectedDuration, duration) {
        case (.quick, .quick), (.standard, .standard), (.deep, .deep): return true
        default: return false
        }
    }

    // Custom slider, shown when "Custom" tapped.
    private var durationSlider: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Text("10 min")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
                Text("\(Int(customMinutes)) min")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                    .monospacedDigit()
                Spacer()
                Text("180 min")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            Slider(value: $customMinutes, in: 10...180, step: 5)
                .tint(DS.Color.teal)
                .onChange(of: customMinutes) { _, v in
                    selectedDuration = .custom(v * 60)
                }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var dndReminder: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(DS.Color.teal)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Do Not Disturb")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textPrimary)
                Text("DoomScroll can block apps, but iOS controls calls and notifications. Pull down Control Centre and enable Focus to silence them.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.tealMuted, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var startButton: some View {
        VStack(spacing: DS.Spacing.sm) {
            DSPrimaryButton(label: "Start \(selectedDuration.label) focus") {
                focusManager.startSession(
                    focusAppName: focusAppName,
                    duration: selectedDuration,
                    existingSelection: existingSelection
                )
                dismiss()
            }

            Text("You can end early, but you'll go through a brief reflection first.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}
