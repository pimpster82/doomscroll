import SwiftUI

// Central design system — all colors, type, and spacing live here.
// Dark #0D0D1A is intentionally reserved ONLY for the shield overlay (ShieldConfigurationExtension).
// The main app uses warm neutrals so it doesn't feel like the feeds it's fighting.
enum DS {

    // MARK: - Colors

    enum Color {
        // Backgrounds
        static let background       = SwiftUI.Color(hex: "FDF5EB")   // Warm off-white
        static let backgroundCard   = SwiftUI.Color(hex: "FFFFFF")
        static let backgroundMuted  = SwiftUI.Color(hex: "F2EBE0")

        // Text
        static let textPrimary      = SwiftUI.Color(hex: "1E1B2E")   // Warm indigo-black
        static let textSecondary    = SwiftUI.Color(hex: "6B6580")
        static let textTertiary     = SwiftUI.Color(hex: "A09AB0")

        // Accent — warm amber (encouragement, never alarm)
        static let accent           = SwiftUI.Color(hex: "F58B44")
        static let accentMuted      = SwiftUI.Color(hex: "FDECD9")

        // Teal — calm / nature
        static let teal             = SwiftUI.Color(hex: "52B6DE")
        static let tealMuted        = SwiftUI.Color(hex: "DFF0F9")

        // Success / streak
        static let success          = SwiftUI.Color(hex: "4CAF6F")
        static let successMuted     = SwiftUI.Color(hex: "DCF5E7")

        // Warning — amber, NOT red (no punishment framing)
        static let warning          = SwiftUI.Color(hex: "F5C144")
        static let warningMuted     = SwiftUI.Color(hex: "FEF6D9")

        // Square Eyes mascot palette
        static let mascotBody       = SwiftUI.Color(hex: "E8F4F0")   // Pale mint
        static let mascotEyeFrame   = SwiftUI.Color(hex: "2C3E50")   // Screen bezel dark
        static let mascotIris       = SwiftUI.Color(hex: "4A90D9")   // Screen-glow blue
        static let mascotCheek      = SwiftUI.Color(hex: "F0A07A")   // Warm peach
        static let mascotFeet       = SwiftUI.Color(hex: "C8B8A8")   // Warm grey

        // Shield overlay (dark — intentional contrast with app)
        static let shieldBg         = SwiftUI.Color(hex: "0D0D1A")
        static let shieldBgWarm     = SwiftUI.Color(hex: "1E1B2E")
    }

    // MARK: - Typography
    // SF Pro Rounded for headers — soft curves feel human and non-judgmental

    enum Font {
        static let hero     = SwiftUI.Font.system(size: 56, weight: .bold, design: .rounded)
        static let title    = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2   = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body     = SwiftUI.Font.system(size: 17, weight: .regular, design: .default)
        static let callout  = SwiftUI.Font.system(size: 15, weight: .regular, design: .default)
        static let caption  = SwiftUI.Font.system(size: 13, weight: .regular, design: .default)
        static let label    = SwiftUI.Font.system(size: 11, weight: .semibold, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat  = 10
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let full: CGFloat = 999
    }
}

// MARK: - SwiftUI helpers

extension SwiftUI.Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - UIColor equivalents (for extensions that use UIKit, e.g. ShieldConfigurationExtension)

extension UIColor {
    static let dsBackground      = UIColor(hex: "FDF5EB")
    static let dsBackgroundCard  = UIColor(hex: "FFFFFF")
    static let dsTextPrimary     = UIColor(hex: "1E1B2E")
    static let dsTextSecondary   = UIColor(hex: "6B6580")
    static let dsAccent          = UIColor(hex: "F58B44")
    static let dsSuccess         = UIColor(hex: "4CAF6F")
    static let dsWarning         = UIColor(hex: "F5C144")
    static let dsTeal            = UIColor(hex: "52B6DE")
    // Shield overlay palette — dark by design (overlays on apps)
    static let dsShieldBg        = UIColor(hex: "1E1B2E")
    static let dsShieldButton    = UIColor(hex: "2E2A42")
    static let dsShieldCommit    = UIColor(hex: "1E3A28")

    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }
}

// Card container matching the design system.
struct DSCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(DS.Color.backgroundCard, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .shadow(color: DS.Color.textPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// Section label chip (uppercase, spaced).
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DS.Font.label)
            .foregroundStyle(DS.Color.textSecondary)
            .textCase(.uppercase)
            .kerning(0.8)
    }
}
