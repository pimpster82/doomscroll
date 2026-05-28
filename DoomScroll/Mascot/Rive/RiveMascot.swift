import SwiftUI
import RiveRuntime

// MARK: - RiveMascot
//
// Drop-in MascotStyle implementation powered by a Rive (.riv) file.
//
// Activate in DoomScrollApp.activeMascot once square_eyes.riv is in the bundle:
//
//   private var activeMascot: any MascotStyle {
//       RiveMascot(
//           fileName: "square_eyes",
//           season: SeasonalTheme.current,
//           seasonEnabled: seasonalFitEnabled
//       )
//   }
//
// The .riv file must contain:
//   - Artboard name:       "Mascot"
//   - State machine name:  "MoodMachine"
//   - Inputs (see DesignerBriefing.md):
//       "Mood"   — Number  (0–6, one per MascotMood)
//       "Season" — Number  (0 = none, 1 = winter, 2 = halloween, 3 = spring, 4 = world cup)
//       "React"  — Trigger (one-shot reaction clip)

struct RiveMascot: MascotStyle {

    // MARK: - Configuration

    /// Base name of the .riv file (without extension) in the main bundle.
    let fileName: String

    /// Artboard name inside the .riv file. Default matches the designer spec.
    var artboardName: String = "Mascot"

    /// State machine name inside the artboard. Default matches the designer spec.
    var stateMachineName: String = "MoodMachine"

    /// Which seasonal layer to show. Pass `SeasonalTheme.current` for auto-detection.
    var season: SeasonalTheme? = nil

    /// Whether the seasonal layer is shown at all (user toggle: "Seasonal Fits").
    var seasonEnabled: Bool = true

    // MARK: - MascotStyle

    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> AnyView {
        AnyView(
            RiveMascotView(
                fileName: fileName,
                artboardName: artboardName,
                stateMachineName: stateMachineName,
                mood: mood,
                season: seasonEnabled ? season : nil,
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
    static let mood   = "Mood"
    /// Number input: 0 = no season, 1–4 = winter/halloween/spring/worldCup.
    static let season = "Season"
    /// Trigger input: fires a one-shot reaction animation then returns to current mood.
    static let react  = "React"
}

// MARK: - Mood → Float mapping
//
// Keep in sync with DesignerBriefing.md and the Rive state machine.

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
    let season: SeasonalTheme?
    let size: CGFloat
    let animated: Bool

    // Each combination of (fileName, artboardName, stateMachineName) gets its own
    // StateObject. Because SwiftUI re-uses the same view struct for all mood/season
    // updates, the single @StateObject persists and we drive transitions purely
    // through setInput / triggerInput — no re-initialisation needed.
    @StateObject private var viewModel: RiveMascotViewModel

    init(
        fileName: String,
        artboardName: String,
        stateMachineName: String,
        mood: MascotMood,
        season: SeasonalTheme?,
        size: CGFloat,
        animated: Bool
    ) {
        self.fileName = fileName
        self.artboardName = artboardName
        self.stateMachineName = stateMachineName
        self.mood = mood
        self.season = season
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
            // Push initial state as soon as the view appears.
            .onAppear {
                viewModel.apply(mood: mood, season: season, animated: animated)
            }
            // React to mood changes from the parent.
            .onChange(of: mood) { newMood in
                viewModel.apply(mood: newMood, season: season, animated: animated)
            }
            // React to season toggle from settings or date rollover.
            .onChange(of: season) { newSeason in
                viewModel.apply(mood: mood, season: newSeason, animated: animated)
            }
            // Broadcast trigger from MascotStyle.triggerReaction().
            .onReceive(NotificationCenter.default.publisher(for: .riveMascotReact)) { _ in
                guard animated else { return }
                viewModel.react()
            }
    }
}

// MARK: - RiveMascotViewModel

/// ObservableObject wrapper so that the RiveViewModel survives SwiftUI view
/// identity changes without being recreated.
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

    /// Push mood and season into the state machine.
    /// When `animated` is false (WidgetKit snapshot) all input calls are skipped;
    /// the runtime shows the first frame of the artboard (neutral idle pose).
    func apply(mood: MascotMood, season: SeasonalTheme?, animated: Bool) {
        guard animated else { return }
        riveVM.setInput(RiveInput.mood,   value: mood.riveValue)
        riveVM.setInput(RiveInput.season, value: season?.riveValue ?? 0)
    }

    /// Fire the one-shot Trigger input. The character plays a reaction clip
    /// then automatically returns to the current mood state.
    func react() {
        riveVM.triggerInput(RiveInput.react)
    }
}
