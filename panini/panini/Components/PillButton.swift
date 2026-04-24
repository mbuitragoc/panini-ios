import SwiftUI

// MARK: - PillButtonStyle

enum PillButtonStyle {
    case primary
    case secondary
    case glass      // iOS 26 liquid glass — replaces the old ghost variant
}

// MARK: - PillButton

/// Capsule button that embraces iOS 26 liquid glass for the glass variant.
struct PillButton: View {
    let title: String
    let style: PillButtonStyle
    let compact: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    init(
        title: String,
        style: PillButtonStyle = .primary,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.compact = compact
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyStyle(size: compact ? 13 : 15, weight: .semibold)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 8 : 14)
                .padding(.horizontal, compact ? 14 : 0)
                .background { buttonBackground }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            Capsule().fill(theme.primary)
        case .secondary:
            Capsule().fill(theme.chip)
        case .glass:
            // iOS 26: real liquid glass material on the capsule shape
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:  theme.primaryInk
        case .secondary: theme.inkSoft
        case .glass:    theme.ink
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "F7EFE1").ignoresSafeArea()
        VStack(spacing: 16) {
            PillButton(title: "Add to collection", style: .primary) {}
            PillButton(title: "Browse album", style: .secondary) {}
            PillButton(title: "Skip", style: .glass, compact: true) {}
        }
        .padding()
    }
}
