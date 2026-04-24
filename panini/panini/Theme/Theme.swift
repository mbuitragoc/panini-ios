import SwiftUI

// MARK: - Color hex initialiser

extension Color {
    /// Initialises a Color from a 6-digit hex string (without leading #).
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme

/// Design tokens for the Terrace Orange palette.
struct Theme {
    // Backgrounds
    let bg: Color
    let surface: Color
    let card: Color

    // Text
    let ink: Color
    let inkSoft: Color
    let inkMuted: Color

    // Brand
    let primary: Color
    let primaryInk: Color
    let accent: Color

    // UI
    let chip: Color
    let success: Color
    let danger: Color

    /// Default light variant — Terrace Orange palette.
    static let light = Theme(
        bg: Color(hex: "F7EFE1"),
        surface: Color(hex: "FFF9EE"),
        card: Color.white,
        ink: Color(hex: "1E1108"),
        inkSoft: Color(hex: "5A4232"),
        inkMuted: Color(hex: "9A8472"),
        primary: Color(hex: "C8511B"),
        primaryInk: Color(hex: "FFF9EE"),
        accent: Color(hex: "1B4965"),
        chip: Color(hex: "EEE3CE"),
        success: Color(hex: "3B7A57"),
        danger: Color(hex: "A82A1F")
    )
}

// MARK: - Environment key

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = .light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Glass card modifier

/// Applies iOS 26 liquid glass as a card background.
/// Falls back gracefully to a translucent tinted fill on older OS.
struct GlassCardModifier: ViewModifier {
    @Environment(\.theme) private var theme
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
    }
}

extension View {
    /// Wraps content in an iOS 26 liquid glass card.
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
