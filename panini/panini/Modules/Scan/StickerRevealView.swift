import SwiftUI

// MARK: - StickerRevealView

/// Full-screen reveal shown when a brand-new sticker is added to the collection.
/// Plays a confetti burst + ring pulse, then surfaces the sticker card and player info.
struct StickerRevealView: View {
    let sticker: Sticker

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var cardVisible   = false
    @State private var infoVisible   = false
    @State private var buttonVisible = false

    private let previewCollection = UserCollection(userID: "", stickerID: "", quantityOwned: 1)

    var body: some View {
        ZStack {
            Color(hex: "1E1108").ignoresSafeArea()

            ringLayer

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    if cardVisible { ConfettiView() }

                    StickerCard(
                        sticker: sticker,
                        collection: previewCollection,
                        width: 200
                    )
                    .scaleEffect(cardVisible ? 1 : 0.15)
                    .opacity(cardVisible ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.65), value: cardVisible)
                }

                playerInfo
                    .opacity(infoVisible ? 1 : 0)
                    .offset(y: infoVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.35), value: infoVisible)
                    .padding(.top, 28)

                Spacer()

                doneButton
                    .opacity(buttonVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: buttonVisible)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 52)
            }
        }
        .onAppear {
            cardVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { infoVisible   = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1)  { buttonVisible = true }
        }
    }

    // MARK: - Player info

    private var playerInfo: some View {
        VStack(spacing: 6) {
            if let name = sticker.playerName {
                Text(name)
                    .displayStyle(size: 28)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 6) {
                Text(sticker.nationalTeam)
                    .bodyStyle(size: 14, weight: .medium)
                    .foregroundStyle(.white.opacity(0.7))

                if let pos = sticker.position {
                    Text("·").foregroundStyle(.white.opacity(0.35))
                    Text(pos)
                        .bodyStyle(size: 14)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(sticker.id)
                .monoStyle(size: 12)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Done button

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("Done")
                .bodyStyle(size: 17, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
        }
    }

    // MARK: - Ring pulses

    private var ringLayer: some View {
        ZStack {
            PulsingRing(color: Color(hex: "C8511B"),              delay: 0.0)
            PulsingRing(color: Color(hex: "C8511B").opacity(0.6), delay: 0.5)
            PulsingRing(color: Color(hex: "C8511B").opacity(0.3), delay: 1.0)
        }
    }
}

// MARK: - PulsingRing

private struct PulsingRing: View {
    let color: Color
    let delay: Double

    @State private var scale:   CGFloat = 0.2
    @State private var opacity: Double  = 0.9

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2.5)
            .frame(width: 240, height: 240)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.8)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    scale   = 2.2
                    opacity = 0
                }
            }
    }
}

// MARK: - ConfettiView

private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = (0..<64).map { _ in ConfettiParticle() }
    @State private var fired = false

    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { i in
                ConfettiPiece(particle: particles[i], fired: fired)
            }
        }
        .onAppear { fired = true }
    }
}

private struct ConfettiParticle {
    let color:    Color
    let finalX:   CGFloat
    let finalY:   CGFloat
    let rotation: Double
    let w:        CGFloat
    let h:        CGFloat
    let delay:    Double

    init() {
        let palette: [Color] = [
            Color(hex: "C8511B"), Color(hex: "F1BF00"), Color(hex: "1B4965"),
            Color(hex: "3B7A57"), Color(hex: "A82A1F"), .white,
            Color(hex: "FCD116"), Color(hex: "5EB6E4"),
        ]
        color = palette.randomElement()!
        let angle    = Double.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 90...260)
        finalX   = cos(angle) * distance
        finalY   = sin(angle) * distance + CGFloat.random(in: 10...80)
        rotation = Double.random(in: 0...540)
        w        = CGFloat.random(in: 6...14)
        h        = CGFloat.random(in: 3...7)
        delay    = Double.random(in: 0...0.22)
    }
}

private struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let fired:    Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(particle.color)
            .frame(width: particle.w, height: particle.h)
            .rotationEffect(.degrees(fired ? particle.rotation : 0))
            .offset(x: fired ? particle.finalX : 0, y: fired ? particle.finalY : 0)
            .opacity(fired ? 0 : 1)
            .animation(.easeOut(duration: 1.5).delay(particle.delay), value: fired)
    }
}
