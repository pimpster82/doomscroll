import SwiftUI

// Square Eyes — DoomScroll's mascot.
// A pale mint blob with dark square screen-bezels for eyes and a glowing blue iris.
// Slightly worried by default: a creature that's already spent too much time staring at
// screens and wants to help you avoid the same fate.
//
// All geometry is SwiftUI primitives — no image assets needed.
// Drive `expression` to animate state transitions.

enum SquareEyesExpression: Equatable {
    case idle           // Half-open, slightly sleepy
    case happy          // Curved arc eyes, cheek blush, small arms raised
    case concerned      // Wide eyes, small iris shifted up, eyebrows
    case sleepy         // Very squished eyes, barely-visible iris
    case proud          // Full bright eyes, enlarged iris
    case disappointed   // Downward gaze, drooping lids
}

struct SquareEyesView: View {
    var expression: SquareEyesExpression = .idle
    var size: CGFloat = 120    // Width; height is 1.16× width
    var animated: Bool = true  // false for WidgetKit snapshots

    // Idle breathing animation
    @State private var breathingOffset: CGFloat = 0
    @State private var blinkOpen: Bool = true
    @State private var blinkTimer: Timer?

    private var height: CGFloat { size * 1.16 }
    private var eyeSize: CGFloat { size * 0.28 }
    private var irisSize: CGFloat { eyeSize * 0.59 }
    private var eyeCorner: CGFloat { eyeSize * 0.24 }

    // Expression-driven values
    private var eyeScaleY: CGFloat {
        switch expression {
        case .idle:          return blinkOpen ? 0.65 : 0.05
        case .happy:         return 0.8
        case .concerned:     return 1.0
        case .sleepy:        return blinkOpen ? 0.22 : 0.05
        case .proud:         return 1.0
        case .disappointed:  return blinkOpen ? 0.5 : 0.05
        }
    }

    private var irisScale: CGFloat {
        switch expression {
        case .idle:         return 0.85
        case .happy:        return 0.0   // replaced by arc
        case .concerned:    return 0.6
        case .sleepy:       return 0.3
        case .proud:        return 1.1
        case .disappointed: return 0.75
        }
    }

    private var irisOffset: CGSize {
        switch expression {
        case .concerned:    return CGSize(width: 0, height: -eyeSize * 0.15)
        case .disappointed: return CGSize(width: 0, height: eyeSize * 0.12)
        default:            return .zero
        }
    }

    private var showCheeks: Bool {
        expression == .happy || expression == .proud
    }

    private var showEyebrows: Bool {
        expression == .concerned
    }

    private var showHappyArc: Bool {
        expression == .happy || expression == .proud
    }

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(DS.Color.mascotBody)
                .frame(width: size, height: height)
                .offset(y: breathingOffset)

            // Feet
            HStack(spacing: size * 0.14) {
                foot
                foot
            }
            .offset(y: height * 0.46 + breathingOffset)

            // Arms (visible in happy/proud)
            if expression == .happy || expression == .proud {
                HStack(spacing: size * 1.0) {
                    arm(angle: -25)
                    arm(angle: 25)
                }
                .offset(y: breathingOffset * 0.5)
            }

            // Cheeks
            if showCheeks {
                HStack(spacing: size * 0.56) {
                    cheek
                    cheek
                }
                .offset(y: size * 0.08 + breathingOffset)
            }

            // Eyebrows
            if showEyebrows {
                HStack(spacing: size * 0.06) {
                    eyebrow(tilt: -8)
                    eyebrow(tilt: 8)
                }
                .offset(y: -size * 0.07 + breathingOffset)
            }

            // Eyes
            HStack(spacing: size * 0.07) {
                eye(isLeft: true)
                eye(isLeft: false)
            }
            .offset(y: -size * 0.04 + breathingOffset)
        }
        .frame(width: size * 1.4, height: height + size * 0.15)
        .onAppear {
            guard animated else { return }
            startBreathing()
            startBlinking()
        }
        .onDisappear {
            blinkTimer?.invalidate()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: expression)
    }

    // MARK: - Sub-views

    private func eye(isLeft: Bool) -> some View {
        ZStack {
            // Eye frame (the square screen bezel)
            RoundedRectangle(cornerRadius: eyeCorner)
                .fill(DS.Color.mascotEyeFrame)
                .frame(width: eyeSize, height: eyeSize)
                .scaleEffect(y: eyeScaleY)

            if showHappyArc {
                // Happy arc: replace iris with upward curve
                happyArcIris
                    .scaleEffect(y: eyeScaleY)
            } else {
                // Iris circle
                Circle()
                    .fill(DS.Color.mascotIris)
                    .frame(width: irisSize * irisScale, height: irisSize * irisScale)
                    .offset(irisOffset)
                    .scaleEffect(y: eyeScaleY > 0.15 ? 1 : 0)

                // Highlight dot
                Circle()
                    .fill(Color.white)
                    .frame(width: irisSize * 0.28, height: irisSize * 0.28)
                    .offset(x: irisSize * 0.22, y: -irisSize * 0.22 + irisOffset.height)
                    .opacity(eyeScaleY > 0.3 ? 1 : 0)
                    .scaleEffect(y: eyeScaleY > 0.15 ? 1 : 0)
            }
        }
    }

    private var happyArcIris: some View {
        // A simple arc path that curves upward to read as a smile-eye
        Path { path in
            let r = irisSize * 0.45
            path.addArc(
                center: CGPoint(x: eyeSize / 2, y: eyeSize * 0.65),
                radius: r,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: false
            )
        }
        .stroke(DS.Color.mascotIris, style: StrokeStyle(lineWidth: irisSize * 0.28, lineCap: .round))
        .frame(width: eyeSize, height: eyeSize)
    }

    private var foot: some View {
        Capsule()
            .fill(DS.Color.mascotFeet)
            .frame(width: size * 0.18, height: size * 0.08)
    }

    private func arm(angle: Double) -> some View {
        Capsule()
            .fill(DS.Color.mascotBody.opacity(0.85))
            .overlay(
                Capsule().stroke(DS.Color.mascotFeet.opacity(0.4), lineWidth: 1)
            )
            .frame(width: size * 0.08, height: size * 0.22)
            .rotationEffect(.degrees(angle))
    }

    private var cheek: some View {
        Circle()
            .fill(DS.Color.mascotCheek.opacity(0.55))
            .frame(width: size * 0.13, height: size * 0.13)
    }

    private func eyebrow(tilt: Double) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(DS.Color.mascotEyeFrame)
            .frame(width: eyeSize * 0.7, height: eyeSize * 0.12)
            .rotationEffect(.degrees(tilt))
    }

    // MARK: - Animations

    private func startBreathing() {
        withAnimation(
            .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
        ) {
            breathingOffset = -3
        }
    }

    private func startBlinking() {
        scheduleNextBlink()
    }

    private func scheduleNextBlink() {
        let interval = Double.random(in: 2.5...5.5)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.08)) { blinkOpen = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.1)) { blinkOpen = true }
                scheduleNextBlink()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            VStack {
                SquareEyesView(expression: .idle)
                Text("idle").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
            }
            VStack {
                SquareEyesView(expression: .happy)
                Text("happy").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
            }
            VStack {
                SquareEyesView(expression: .concerned)
                Text("concerned").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
            }
        }
        HStack(spacing: 24) {
            VStack {
                SquareEyesView(expression: .sleepy)
                Text("sleepy").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
            }
            VStack {
                SquareEyesView(expression: .proud)
                Text("proud").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
            }
            VStack {
                SquareEyesView(expression: .disappointed)
                Text("disappointed").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
            }
        }
    }
    .padding(32)
    .background(DS.Color.background)
}
