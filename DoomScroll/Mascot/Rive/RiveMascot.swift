import SwiftUI
import RiveRuntime

// MARK: - RiveMascot
//
// Drop-in MascotStyle implementation powered by a Rive (.riv) file.
//
// Slot it in with one line in DoomScrollApp:
//
//   private var activeMascot: any MascotStyle {
//       let base = RiveMascot(fileName: "square_eyes")
//       if let theme = SeasonalTheme.current {
//           return SeasonalOverlay(base: base, theme: theme)
//       }
//       return base
//   }
//
// The .riv file must contain:
//   - Artboard name:       "Mascot"
//   - State machine name:  "MoodMachine"
//   - Inputs (see RiveMascot.Input):
//       "Mood"     — Number  (maps each MascotMood to a Float constant below)
//       "React"    — Trigger (one-shot for triggerReaction())
//
// See DesignerBriefing.md (next to this file) for the full Rive editor spec.

struct RiveMascot: MascotStyle {

    // MARK: - Configuration

    /// Base name of the .riv file (without extension) in the main bundle.
    let fileName: String

    /// Artboard name inside the .riv file. Default matches the designer spec.
    var artboardName: String = "Mascot"

    /// State machine name inside the artboard. Default matches the designer spec.
    var stateMachineName: String = "MoodMachine"

    // MARK: - MascotStyle

    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> AnyView {
        AnyView(
            RiveMascotView(
                fileName: fileName,
                artboardName: artboardName,
                stateMachineName: stateMachineName,
                mood: mood,
                size: size,
                animated: animated
            )
        )
    }

    // triggerReaction() is handled inside RiveMascotView via a Notification so
    // that it can reach whichever live RiveViewModel is currently on screen.
    func triggerReaction() {
        NotificationCenter.default.post(name: .riveMascotReact, object: nil)
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let riveMascotReact = Notification.Name("com.doomscroll.riveMascot.react")
}

// MARK: - Input names (single source of truth shared with the .riv file)

private enum RiveInput {
    /// Number input: controls which mood state the mascot is in.
    static let mood  = "Mood"
    /// Trigger input: fires a one-shot reaction animation then returns to current mood.
    static let react = "React"
}

// MARK: - Mood → Float mapping
//
// The designer creates numbered states in the MoodMachine driven by the "Mood" number
// input.  Each MascotMood maps to a distinct float so the state machine can transition
// with conditions like "Mood == 0 → Idle", "Mood == 1 → Happy", etc.
// Keep these values in sync with the Rive editor (see DesignerBriefing.md).

private extension MascotMood {
    var riveValue: Float {
        switch self {
        case .idle:          return 0
        case .happy:         return 1
        case .proud:         return 2
        case .concerned:     return 3
        case .sleepy:        return 4
        case .disappointed:  return 5
        case .celebrating:   return 6
        }
    }
}

// MARK: - RiveMascotView

/// Internal SwiftUI view that owns the RiveViewModel lifecycle.
/// Not exposed outside this file; call sites use MascotView → RiveMascot.view().
private struct RiveMascotView: View {

    let fileName: String
    let artboardName: String
    let stateMachineName: String
    let mood: MascotMood
    let size: CGFloat
    let animated: Bool

    // Each combination of (fileName, artboardName, stateMachineName) gets its own
    // StateObject. Because SwiftUI re-uses the same view struct for all mood updates,
    // the single @StateObject persists across mood changes and we drive transitions
    // purely through setInput / triggerInput — no re-initialisation needed.
    @StateObject private var viewModel: RiveMascotViewModel

    init(
        fileName: String,
        artboardName: String,
        stateMachineName: String,
        mood: MascotMood,
        size: CGFloat,
        animated: Bool
    ) {
        self.fileName = fileName
        self.artboardName = artboardName
        self.stateMachineName = stateMachineName
        self.mood = mood
        self.size = size
        self.animated = animated

        _viewModel = StateObject(
            wrappedValue: RiveMascotViewModel(
                fileName: fileName,
                artboardName: artboardName,
                stateMachineName: stateMachineName,
                autoPlay: animated
            )
        )
    }

    var body: some View {
        viewModel.riveVM
            .view()
            // Size the canvas to a square; Rive's .fit(.contain) keeps aspect ratio.
            .frame(width: size, height: size)
            // Push the initial mood as soon as the view appears.
            .onAppear {
                viewModel.apply(mood: mood, animated: animated)
            }
            // React whenever the parent changes the mood prop.
            .onChange(of: mood) { newMood in
                viewModel.apply(mood: newMood, animated: animated)
            }
            // Broadcast trigger from MascotStyle.triggerReaction().
            .onReceive(NotificationCenter.default.publisher(for: .riveMascotReact)) { _ in
                guard animated else { return }
                viewModel.react()
            }
    }
}

// MARK: - RiveMascotViewModel

/// ObservableObject wrapper so that the RiveViewModel (which is itself an
/// ObservableObject) survives SwiftUI view identity changes without being recreated.
@MainActor
private final class RiveMascotViewModel: ObservableObject {

    let riveVM: RiveViewModel

    init(fileName: String, artboardName: String, stateMachineName: String, autoPlay: Bool) {
        riveVM = RiveViewModel(
            fileName: fileName,
            stateMachineName: stateMachineName,
            fit: .contain,
            alignment: .center,
            autoPlay: autoPlay,
            artboardName: artboardName
        )
    }

    /// Push the current mood into the state machine.
    /// When `animated` is false (WidgetKit snapshot) we skip all input calls so
    /// the runtime renders the first frame of the artboard without advancing.
    func apply(mood: MascotMood, animated: Bool) {
        guard animated else {
            // For static snapshots we want the character frozen.
            // The RiveViewModel was already created with autoPlay: false, so
            // no additional call is required — the first artboard frame is shown.
            return
        }
        riveVM.setInput(RiveInput.mood, value: mood.riveValue)
    }

    /// Fire the one-shot Trigger input so the character plays a short reaction
    /// clip and then automatically returns to the current mood state.
    func react() {
        riveVM.triggerInput(RiveInput.react)
    }
}
