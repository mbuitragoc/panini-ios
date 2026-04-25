import SwiftUI
import UIKit
import SwiftData

// MARK: - StickerRevealView

/// Cinematic reveal played BEFORE a brand-new sticker is committed to the collection.
/// Sequence: backdrop → crest → card → name/position → OVR counter → rarity → CTA.
/// The caller-supplied `onConfirm` performs the actual save and dismissal.
struct StickerRevealView: View {
    let sticker: Sticker
    let onConfirm: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Backdrop + glow
    @State private var backdropVisible = false
    @State private var glowVisible     = false

    // Crest phase
    @State private var crestScale:   Double = 0.6
    @State private var crestOpacity: Double = 0

    // Card + info phase
    @State private var cardVisible     = false
    @State private var nameVisible     = false
    @State private var positionVisible = false
    @State private var statsVisible    = false
    @State private var rarityVisible   = false
    @State private var buttonVisible   = false
    @State private var displayedOVR: Int = 0

    // Legendary extras
    @State private var particlesActive = false
    @State private var haloVisible     = false

    private var hasRating: Bool {
        sticker.type == "player" && sticker.rating != nil
    }

    private var previewCollection: UserCollection {
        UserCollection(userID: "", stickerID: sticker.id, quantityOwned: 1)
    }

    private var teamColors: [Color] { teamGradient(for: sticker.countryCode) }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "1E1108")
                .ignoresSafeArea()
                .opacity(backdropVisible ? 1 : 0)

            radialGlow
                .opacity(glowVisible ? 0.4 : 0)
                .allowsHitTesting(false)

            // Crest layer — centered, fades out before card enters
            crestLayer
                .allowsHitTesting(false)

            // Legendary particle burst
            if sticker.rating?.isLegendary == true {
                ParticleField(
                    colors: [Color(hex: "9B59B6"), Color(hex: "4A90D9"), Color(hex: "C39BD3")],
                    isActive: $particlesActive
                )
            }

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                ZStack {
                    if sticker.rating?.isLegendary == true {
                        CardAura(cardWidth: 200)
                            .opacity(haloVisible ? 1 : 0)
                    }
                    StickerCard(
                        sticker: sticker,
                        collection: previewCollection,
                        width: 200
                    )
                }
                .scaleEffect(cardVisible ? 1 : 0.2)
                .opacity(cardVisible ? 1 : 0)

                playerName
                    .opacity(nameVisible ? 1 : 0)
                    .offset(y: nameVisible ? 0 : 8)
                    .padding(.top, 24)

                positionLabel
                    .opacity(positionVisible ? 1 : 0)
                    .padding(.top, 6)

                if hasRating {
                    statsRow
                        .opacity(statsVisible ? 1 : 0)
                        .padding(.top, 24)
                }

                Spacer()

                confirmButton
                    .opacity(buttonVisible ? 1 : 0)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 52)
            }
        }
        .task { await runSequence() }
    }

    // MARK: - Crest layer

    private var crestLayer: some View {
        VStack(spacing: 20) {
            Image("NationalCrests/\(sticker.countryCode)")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .shadow(
                    color: (teamColors.first ?? .white).opacity(0.5),
                    radius: 32, x: 0, y: 0
                )

            Text(sticker.nationalTeam.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .tracking(3)
        }
        .scaleEffect(crestScale)
        .opacity(crestOpacity)
    }

    // MARK: - Reusable layers

    private var radialGlow: some View {
        GeometryReader { proxy in
            RadialGradient(
                colors: [teamColors.first ?? .white, .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    private var playerName: some View {
        Group {
            if let name = sticker.playerName {
                Text(name)
                    .displayStyle(size: 30)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var positionLabel: some View {
        HStack(spacing: 6) {
            Text(sticker.nationalTeam)
                .bodyStyle(size: 14, weight: .medium)
                .foregroundStyle(.white.opacity(0.75))

            if let pos = sticker.position {
                Text("·").foregroundStyle(.white.opacity(0.35))
                Text(pos)
                    .bodyStyle(size: 14)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            if let rating = sticker.rating {
                Text("\(displayedOVR)")
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundStyle(rating.rarityColor)
                    .monospacedDigit()

                if rarityVisible {
                    RarityBadge(rating: rating, iconSize: 14)
                        .transition(.opacity)
                }
            }
        }
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text("Add to collection")
                .bodyStyle(size: 17, weight: .semibold)
                .foregroundStyle(theme.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Sequence

    private func runSequence() async {
        if reduceMotion {
            await runReducedMotionSequence()
        } else {
            await runFullSequence()
        }
    }

    private func runFullSequence() async {
        // 1. Dark backdrop
        withAnimation(.easeOut(duration: 0.25)) { backdropVisible = true }

        // 2. Glow + crest entrance simultaneously
        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(.easeOut(duration: 0.6)) { glowVisible = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            crestScale   = 1.0
            crestOpacity = 1.0
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        // 3. Hold so user reads the crest (longer for legendary)
        let isLegendary = sticker.rating?.isLegendary == true
        let crestHold: UInt64 = isLegendary ? 1_200_000_000 : 900_000_000
        try? await Task.sleep(nanoseconds: crestHold)

        // 4. Crest exits while card springs in
        withAnimation(.easeIn(duration: 0.3)) {
            crestScale   = 0.3
            crestOpacity = 0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
            cardVisible = true
        }
        if isLegendary {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            particlesActive = true
        }

        // 5. Let card spring settle, then fade in halo for legendary
        try? await Task.sleep(nanoseconds: 500_000_000)
        if isLegendary {
            withAnimation(.easeIn(duration: 0.6)) { haloVisible = true }
        }

        // 6. Name
        withAnimation(.easeOut(duration: 0.35)) { nameVisible = true }

        try? await Task.sleep(nanoseconds: 200_000_000)

        // 7. Position
        withAnimation(.easeOut(duration: 0.3)) { positionVisible = true }

        try? await Task.sleep(nanoseconds: 200_000_000)

        // 8. Stats + OVR counter (legendary gets 2s tick + heavy haptic)
        if hasRating {
            withAnimation(.easeOut(duration: 0.2)) { statsVisible = true }
            let ovrDuration = isLegendary ? 2.0 : 1.2
            await tickOVR(to: sticker.rating?.overall ?? 0, duration: ovrDuration)
            let haptic: UIImpactFeedbackGenerator.FeedbackStyle = isLegendary ? .heavy : .medium
            UIImpactFeedbackGenerator(style: haptic).impactOccurred()
            withAnimation(.easeOut(duration: 0.3)) { rarityVisible = true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        } else {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // 9. CTA
        withAnimation(.easeOut(duration: 0.3)) { buttonVisible = true }
    }

    private func runReducedMotionSequence() async {
        withAnimation(.easeOut(duration: 0.3)) {
            backdropVisible = true
            glowVisible     = true
            cardVisible     = true
            nameVisible     = true
            positionVisible = true
            statsVisible    = hasRating
            rarityVisible   = hasRating
            buttonVisible   = true
        }
        if hasRating {
            displayedOVR = sticker.rating?.overall ?? 0
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func tickOVR(to target: Int, duration: Double) async {
        guard target > 0 else { return }
        let frameInterval: Double = 1.0 / 60.0
        let totalFrames = max(1, Int(duration / frameInterval))
        let start = Date()
        for frame in 0...totalFrames {
            let progress = min(1.0, Double(frame) / Double(totalFrames))
            // Cubic ease-out: punchy at the start, settles smoothly at target.
            let eased = 1 - pow(1 - progress, 3)
            displayedOVR = Int(Double(target) * eased)
            let nextDeadline = start.addingTimeInterval(Double(frame + 1) * frameInterval)
            let remaining = nextDeadline.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
        displayedOVR = target
    }
}

// MARK: - Previews

#Preview("Gold player — Pedri") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Sticker.self, PlayerRating.self, UserCollection.self, configurations: config)
    let ctx = container.mainContext

    let sticker = Sticker(id: "ESP-11", countryCode: "ESP", stickerNumber: 11,
                          type: "player", playerName: "Pedri", position: "CAM",
                          nationalTeam: "Spain")
    let rating = PlayerRating(stickerID: "ESP-11", overall: 87,
                              pace: 79, shooting: 78, passing: 88,
                              dribbling: 91, defending: 45, physical: 66,
                              nationPosition: "CAM", nationJerseyNumber: 8,
                              playStyles: ["Finesse Shot", "Quick Step", "Technical"],
                              rarity: "gold", confidence: "exact")
    ctx.insert(sticker)
    ctx.insert(rating)
    sticker.rating = rating
    rating.sticker = sticker

    return StickerRevealView(sticker: sticker, onConfirm: {})
        .modelContainer(container)
}

#Preview("Legendary — Mbappe") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Sticker.self, PlayerRating.self, UserCollection.self, configurations: config)
    let ctx = container.mainContext

    let sticker = Sticker(id: "FRA-16", countryCode: "FRA", stickerNumber: 16,
                          type: "player", playerName: "Kylian Mbappé", position: "ST",
                          nationalTeam: "France")
    let rating = PlayerRating(stickerID: "FRA-16", overall: 93,
                              pace: 97, shooting: 90, passing: 82,
                              dribbling: 93, defending: 36, physical: 76,
                              nationPosition: "ST", nationJerseyNumber: 10,
                              playStyles: ["Rapid", "Finesse Shot", "Acrobatic", "Trickster"],
                              rarity: "legendary", confidence: "exact")
    ctx.insert(sticker)
    ctx.insert(rating)
    sticker.rating = rating
    rating.sticker = sticker

    return StickerRevealView(sticker: sticker, onConfirm: {})
        .modelContainer(container)
}

#Preview("No rating — placeholder") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Sticker.self, PlayerRating.self, UserCollection.self, configurations: config)
    let ctx = container.mainContext

    let sticker = Sticker(id: "COL-10", countryCode: "COL", stickerNumber: 10,
                          type: "player", playerName: "James Rodríguez", position: "CAM",
                          nationalTeam: "Colombia")
    ctx.insert(sticker)

    return StickerRevealView(sticker: sticker, onConfirm: {})
        .modelContainer(container)
}

#Preview("Badge sticker") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Sticker.self, PlayerRating.self, UserCollection.self, configurations: config)
    let ctx = container.mainContext

    let sticker = Sticker(id: "BRA-1", countryCode: "BRA", stickerNumber: 1,
                          type: "badge", nationalTeam: "Brazil")
    ctx.insert(sticker)

    return StickerRevealView(sticker: sticker, onConfirm: {})
        .modelContainer(container)
}
