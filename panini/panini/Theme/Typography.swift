import SwiftUI

// MARK: - Font helpers

/// Returns the DM Serif Display italic font at the given size.
func displayFont(size: CGFloat) -> Font {
    Font.custom("DM Serif Display", size: size).italic()
}

/// Returns the Inter font at the given size and weight.
/// Uses PostScript face names directly to avoid font descriptor weight synthesis warnings.
func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    let face: String
    switch weight {
    case .ultraLight:   face = "Inter-ExtraLight"
    case .thin:         face = "Inter-Thin"
    case .light:        face = "Inter-Light"
    case .medium:       face = "Inter-Medium"
    case .semibold:     face = "Inter-SemiBold"
    case .bold:         face = "Inter-Bold"
    case .heavy:        face = "Inter-ExtraBold"
    case .black:        face = "Inter-Black"
    default:            face = "Inter-Regular"
    }
    return Font.custom(face, size: size)
}

/// Returns the JetBrains Mono font at the given size.
func monoFont(size: CGFloat) -> Font {
    Font.custom("JetBrains Mono", size: size)
}

// MARK: - ViewModifiers

/// Applies the display (DM Serif Display italic) style.
struct DisplayStyle: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        content.font(displayFont(size: size))
    }
}

/// Applies the body (Inter) style.
struct BodyStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(bodyFont(size: size, weight: weight))
    }
}

/// Applies the mono (JetBrains Mono) style.
struct MonoStyle: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        content.font(monoFont(size: size))
    }
}

// MARK: - View extensions

extension View {
    /// Applies the display font style.
    func displayStyle(size: CGFloat = 32) -> some View {
        modifier(DisplayStyle(size: size))
    }

    /// Applies the body font style.
    func bodyStyle(size: CGFloat = 16, weight: Font.Weight = .regular) -> some View {
        modifier(BodyStyle(size: size, weight: weight))
    }

    /// Applies the mono font style.
    func monoStyle(size: CGFloat = 13) -> some View {
        modifier(MonoStyle(size: size))
    }
}
