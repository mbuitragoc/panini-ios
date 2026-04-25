import SwiftUI

// MARK: - CardAura

/// Three-layer legendary glow that wraps tightly around a sticker card.
///
/// All layers use `RoundedRectangle` + `.blur()` so the glow hugs the card
/// silhouette instead of spilling out as a large circle.
///
/// Layer 1 — Blurred inner glow:   purple, breathes opacity
/// Layer 2 — Rotating aurora:      angular purple↔blue gradient, blurred, rotates
/// Layer 3 — Rim light:            crisp lavender stroke on the card edge, oscillates
struct CardAura: View {
    let cardWidth: CGFloat
    var cornerRadius: CGFloat = 12

    private var cardHeight: CGFloat { cardWidth * 1.4 }

    @State private var breathOpacity: Double = 0.45
    @State private var rimOpacity:    Double = 0.35
    @State private var auroraAngle:   Double = 0

    private let purple   = Color(hex: "9B59B6")
    private let blue     = Color(hex: "4A90D9")
    private let lavender = Color(hex: "E0C8FF")

    var body: some View {
        ZStack {
            // Layer 2 — Rotating aurora: card-shaped, angular gradient, soft blur
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    AngularGradient(
                        colors: [
                            purple.opacity(0.50),
                            blue.opacity(0.40),
                            purple.opacity(0.15),
                            .clear,
                            blue.opacity(0.30),
                            purple.opacity(0.50),
                        ],
                        center: .center
                    )
                )
                .frame(width: cardWidth + 10, height: cardHeight + 10)
                .blur(radius: 14)
                .rotationEffect(.degrees(auroraAngle))

            // Layer 1 — Inner glow: pure purple fill, blurred to hug card edges
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(purple)
                .frame(width: cardWidth, height: cardHeight)
                .blur(radius: 18)
                .opacity(breathOpacity)

            // Layer 3 — Rim light: crisp stroke just outside the card
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(lavender, lineWidth: 1.5)
                .frame(width: cardWidth + 1, height: cardHeight + 1)
                .opacity(rimOpacity)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            breathOpacity = 0.80
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            rimOpacity = 1.0
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            auroraAngle = 360
        }
    }
}
