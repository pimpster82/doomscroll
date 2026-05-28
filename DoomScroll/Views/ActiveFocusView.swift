import SwiftUI

// Shown on the dashboard when a focus session is active.
// Countdown timer, mascot reacting to progress, and early-exit friction.
struct ActiveFocusView: View {
    @EnvironmentObject var focusManager: FocusModeManager
    @State private var now = Date()
    @State private var showEarlyExitFlow = false
    @State private var earlyExitStep = 0    // 0=impact, 1=reflection, 2=confirm

    // Tick the timer every second.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var session: FocusSession? { focusManager.activeSession }

    private var mascotMood: MascotMood {
        guard let s = session else { return .idle }
        if s.progressFraction > 0.9 { return .proud }
        if s.progressFraction > 0.5 { return .happy }
        return .idle
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if let session {
                focusCard(session: session)
                if showEarlyExitFlow {
                    earlyExitCard(session: session)
                }
            }
        }
        .onReceive(timer) { _ in
            now = Date()
            // Check for natural session end.
            if let s = focusManager.activeSession, !s.isActive {
                focusManager.endSession(early: false)
            }
        }
    }

    // MARK: - Focus card

    private func focusCard(session: FocusSession) -> some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                SectionLabel(text: "Focus session")
                Spacer()
                // Pulsing green dot to signal active.
                Circle()
                    .fill(DS.Color.success)
                    .frame(width: 8, height: 8)
            }

            HStack(alignment: .center, spacing: DS.Spacing.xl) {
                // Mascot reacts to progress.
                MascotView(mood: mascotMood, size: 72)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(session.focusAppName)
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textPrimary)

                    // Ring + remaining time.
                    HStack(spacing: DS.Spacing.sm) {
                        progressRing(fraction: session.progressFraction)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatRemaining(session.remainingSeconds))
                                .font(DS.Font.title2)
                                .foregroundStyle(DS.Color.textPrimary)
                                .monospacedDigit()
                            Text("remaining")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                Spacer()
            }

            // Attempt indicator.
            if session.earlyExitAttempts > 0 {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.warning)
                    Text("\(session.earlyExitAttempts) early-exit attempt\(session.earlyExitAttempts == 1 ? "" : "s") this session")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            // End early button.
            if !showEarlyExitFlow {
                Button {
                    focusManager.recordEarlyExitAttempt()
                    withAnimation { showEarlyExitFlow = true; earlyExitStep = 0 }
                } label: {
                    Text("End session early")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: DS.Color.textPrimary.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Early-exit friction

    // The friction here is inverted from normal DoomScroll:
    // not "why are you opening this app?" but "you chose to focus — what changed?"
    private func earlyExitCard(session: FocusSession) -> some View {
        let prompt = session.earlyExitPrompt

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                MascotView(mood: .concerned, size: 52)
                Text(earlyExitStep == 0 ? prompt.impactLine : prompt.reflectionQuestion)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DS.Spacing.sm) {
                // Keep focusing — always the prominent option.
                Button {
                    withAnimation { showEarlyExitFlow = false; earlyExitStep = 0 }
                } label: {
                    Text(earlyExitStep == 0 ? prompt.continueLabel : "Keep going")
                        .font(DS.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.success, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                // End — de-emphasised, requires two taps (impact then confirm).
                if earlyExitStep == 0 {
                    Button {
                        withAnimation { earlyExitStep = 1 }
                    } label: {
                        Text("I need to stop")
                            .font(DS.Font.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Color.backgroundMuted, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        focusManager.endSession(early: true)
                        showEarlyExitFlow = false
                    } label: {
                        Text(prompt.confirmLabel)
                            .font(DS.Font.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Color.warningMuted, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                            .foregroundStyle(DS.Color.warning)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.accentMuted, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func progressRing(fraction: Double) -> some View {
        ZStack {
            Circle()
                .stroke(DS.Color.backgroundMuted, lineWidth: 5)
                .frame(width: 40, height: 40)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(DS.Color.success, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
