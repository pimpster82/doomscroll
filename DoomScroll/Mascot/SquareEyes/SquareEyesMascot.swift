import SwiftUI

// Square Eyes — the app's default mascot character.
// Conforms to MascotStyle; all rendering delegated to SquareEyesView.
// To swap to a different character: create a new MascotStyle conformer and
// change the .mascot() injection in DoomScrollApp — nothing else changes.
struct SquareEyesMascot: MascotStyle {
    func view(mood: MascotMood, size: CGFloat, animated: Bool) -> AnyView {
        AnyView(SquareEyesView(expression: mood, size: size, animated: animated))
    }
}
