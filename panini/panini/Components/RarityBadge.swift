import SwiftUI
import SwiftData

// MARK: - RarityBadge

/// Compact tier badge: shape icon + label. Used in OVR strips and reveal screens.
struct RarityBadge: View {
    let rating: PlayerRating
    var iconSize: CGFloat = 12
    var glintPhase: Double = 12.0   // forwarded to RarityIcon for legendary spike glints

    var body: some View {
        HStack(spacing: 6) {
            RarityIcon(rarity: rating.rarity, size: iconSize, glintPhase: glintPhase)
            Text(rating.rarity.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(rating.rarityColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(rating.rarityColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(rating.rarityColor.opacity(0.4), lineWidth: 1.5))
    }
}

// MARK: - RarityIcon

/// Standalone tier shape icon drawn with Canvas.
///
/// - Bronze    `< 75 OVR` — radial-gradient coin with inner rim stroke
/// - Silver    `75–81`    — faceted octagon (22.5° rotation, alternating triangle fills)
/// - Gold      `82–88`    — 8-point star + inner sun disc + 4 tapered radiating rays
/// - Legendary `89+`      — hexagram + containment ring + 12-spike crown + animated dotted halo (≥32pt)
struct RarityIcon: View {
    let rarity: String
    var size: CGFloat = 16
    var glintPhase: Double = 12.0   // 0→12 fires sequential spike glints (legendary only)

    var body: some View {
        Group {
            if rarity == "legendary" && size >= 32 {
                // Animated halo ring for large legendary icons
                TimelineView(.animation) { tl in
                    let rotDeg = tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 4.0) / 4.0 * 360.0
                    Canvas { ctx, sz in paint(&ctx, sz: sz, rotDeg: rotDeg) }
                }
            } else {
                Canvas { ctx, sz in paint(&ctx, sz: sz, rotDeg: 0) }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Dispatch

    private func paint(_ ctx: inout GraphicsContext, sz: CGSize, rotDeg: Double) {
        switch rarity {
        case "legendary": legendary(&ctx, sz: sz, rotDeg: rotDeg)
        case "gold":      gold(&ctx, sz: sz)
        case "silver":    silver(&ctx, sz: sz)
        default:          bronze(&ctx, sz: sz)
        }
    }

    // MARK: - Bronze — Radial gradient coin

    private func bronze(_ ctx: inout GraphicsContext, sz: CGSize) {
        let cx = sz.width / 2, cy = sz.height / 2
        let r  = min(sz.width, sz.height) / 2 * 0.90
        let center = CGPoint(x: cx, y: cy)
        let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

        // Dome-like radial fill: light copper centre → dark copper edge
        ctx.fill(disc, with: .radialGradient(
            Gradient(colors: [Color(hex: "E89B5C"), Color(hex: "A8651F")]),
            center: center, startRadius: 0, endRadius: r
        ))

        // Inner rim — struck-coin feel
        ctx.stroke(disc, with: .color(Color(hex: "7A4A18").opacity(0.65)), lineWidth: 1)
    }

    // MARK: - Silver — Faceted octagon

    private func silver(_ ctx: inout GraphicsContext, sz: CGSize) {
        let cx = sz.width / 2, cy = sz.height / 2
        let r  = min(sz.width, sz.height) / 2 * 0.92
        let center = CGPoint(x: cx, y: cy)

        // Vertices of a regular octagon rotated 22.5° (flat edge points up — shield, not stop-sign)
        let verts: [CGPoint] = (0..<8).map { i in
            let a = (Double(i) * 45.0 + 22.5) * .pi / 180.0
            return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
        }

        let lightSteel = Color(hex: "C8D4E0")
        let darkSteel  = Color(hex: "8A9AAE")

        // 8 triangle facets from centre → alternating light / dark (cut-gem shimmer)
        for i in 0..<8 {
            var facet = Path()
            facet.move(to: center)
            facet.addLine(to: verts[i])
            facet.addLine(to: verts[(i + 1) % 8])
            facet.closeSubpath()
            ctx.fill(facet, with: .color(i.isMultiple(of: 2) ? lightSteel : darkSteel))
        }

        // Outer definition stroke
        var oct = Path()
        oct.move(to: verts[0])
        for i in 1..<8 { oct.addLine(to: verts[i]) }
        oct.closeSubpath()
        ctx.stroke(oct, with: .color(Color(hex: "5A6A7C").opacity(0.8)), lineWidth: 0.8)
    }

    // MARK: - Gold — 8-point star + sun disc + radiating rays

    private func gold(_ ctx: inout GraphicsContext, sz: CGSize) {
        let cx = sz.width / 2, cy = sz.height / 2
        let outerR = min(sz.width, sz.height) / 2 * 0.88
        let innerR = outerR * 0.45
        let sunR   = outerR * 0.32
        let center = CGPoint(x: cx, y: cy)

        // 8-point star body with top-to-bottom gold gradient
        let star = starPath(cx: cx, cy: cy, outerR: outerR, innerR: innerR, points: 8)
        ctx.fill(star, with: .linearGradient(
            Gradient(colors: [Color(hex: "FFD24A"), Color(hex: "F5A623"), Color(hex: "B8740F")]),
            startPoint: CGPoint(x: cx, y: cy - outerR),
            endPoint:   CGPoint(x: cx, y: cy + outerR)
        ))

        // 4 tapered rays from the 4 cardinal axes, breaking slightly past the star silhouette
        let rayTip  = outerR * 1.10
        let rayBase = innerR
        for i in 0..<4 {
            let a = Double(i) * .pi / 2 - .pi / 2   // N, E, S, W
            let perp = a + .pi / 2
            let hw: CGFloat = max(1.0, sz.width * 0.04)
            var ray = Path()
            ray.move(to: CGPoint(
                x: cx + cos(perp) * hw + cos(a) * rayBase,
                y: cy + sin(perp) * hw + sin(a) * rayBase))
            ray.addLine(to: CGPoint(x: cx + cos(a) * rayTip, y: cy + sin(a) * rayTip))
            ray.addLine(to: CGPoint(
                x: cx - cos(perp) * hw + cos(a) * rayBase,
                y: cy - sin(perp) * hw + sin(a) * rayBase))
            ray.closeSubpath()
            ctx.fill(ray, with: .color(Color(hex: "FFE9A8").opacity(0.85)))
        }

        // Inner sun disc — warm pale gold centre
        let sunRect = CGRect(x: cx - sunR, y: cy - sunR, width: sunR * 2, height: sunR * 2)
        ctx.fill(Path(ellipseIn: sunRect), with: .radialGradient(
            Gradient(colors: [Color(hex: "FFFDE0"), Color(hex: "FFE5A0")]),
            center: center, startRadius: 0, endRadius: sunR
        ))

        // Subtle outer stroke
        ctx.stroke(star, with: .color(Color(hex: "7A4E08").opacity(0.55)), lineWidth: 0.8)
    }

    // MARK: - Legendary — Hexagram + crown + animated halo

    private func legendary(_ ctx: inout GraphicsContext, sz: CGSize, rotDeg: Double) {
        let cx     = sz.width / 2, cy = sz.height / 2
        let outerR = min(sz.width, sz.height) / 2 * 0.82
        let center = CGPoint(x: cx, y: cy)

        // 1. Hexagram (6-point star) — dual-colour radial fill (the legendary signature)
        let hex = starPath(cx: cx, cy: cy, outerR: outerR, innerR: outerR * 0.50, points: 6)
        ctx.fill(hex, with: .radialGradient(
            Gradient(colors: [Color(hex: "C39BD3"), Color(hex: "9B59B6"), Color(hex: "4A90D9")]),
            center: center, startRadius: 0, endRadius: outerR
        ))

        // 2. Containment ring just outside the hexagram tips
        let ringR = outerR * 1.02
        let ring  = Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2))
        ctx.stroke(ring, with: .color(Color(hex: "E0C8FF").opacity(0.75)), lineWidth: max(0.6, sz.width * 0.03))

        // 3. Crown — 12 alternating long/short spikes outside the ring
        let spikeBase = ringR
        let longTip   = outerR * 1.32
        let shortTip  = outerR * 1.18
        let spikeHW: CGFloat = max(0.6, sz.width * 0.025)
        for i in 0..<12 {
            let a    = Double(i) * .pi / 6 - .pi / 2
            let perp = a + .pi / 2
            let tip  = i.isMultiple(of: 2) ? longTip : shortTip
            var spike = Path()
            spike.move(to: CGPoint(
                x: cx + cos(perp) * spikeHW + cos(a) * spikeBase,
                y: cy + sin(perp) * spikeHW + sin(a) * spikeBase))
            spike.addLine(to: CGPoint(x: cx + cos(a) * tip, y: cy + sin(a) * tip))
            spike.addLine(to: CGPoint(
                x: cx - cos(perp) * spikeHW + cos(a) * spikeBase,
                y: cy - sin(perp) * spikeHW + sin(a) * spikeBase))
            spike.closeSubpath()
            // Sequential glint: spike i flashes bright as glintPhase sweeps 0→12
            let d         = glintPhase - Double(i)
            let flash     = (d >= 0 && d <= 1) ? sin(d * .pi) : 0.0
            let baseAlpha = i.isMultiple(of: 2) ? 0.95 : 0.65
            ctx.fill(spike, with: .color(
                Color(hex: "E0C8FF").opacity(baseAlpha + (1.0 - baseAlpha) * flash)
            ))
        }

        // 4. Dotted halo ring — only at ≥32pt, rotates when animated
        if sz.width >= 32 {
            let haloR   = outerR * 1.55
            let dotCount = 24
            for i in 0..<dotCount {
                let a       = (Double(i) * 360.0 / Double(dotCount) + rotDeg) * .pi / 180.0
                let dotX    = cx + cos(a) * haloR
                let dotY    = cy + sin(a) * haloR
                let dotSize = i.isMultiple(of: 2) ? CGFloat(2.2) : CGFloat(1.2)
                let alpha   = i.isMultiple(of: 2) ? 0.75 : 0.40
                let dot     = Path(ellipseIn: CGRect(
                    x: dotX - dotSize / 2, y: dotY - dotSize / 2,
                    width: dotSize, height: dotSize))
                ctx.fill(dot, with: .color(Color(hex: "9B59B6").opacity(alpha)))
            }
        }
    }

    // MARK: - Path helpers

    /// Builds a regular star (innerR < outerR) or polygon (innerR == outerR).
    private func starPath(cx: CGFloat, cy: CGFloat, outerR: CGFloat, innerR: CGFloat, points: Int) -> Path {
        var path = Path()
        let step = CGFloat.pi / CGFloat(points)
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * step - CGFloat.pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("All tiers — badges") {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Sticker.self, PlayerRating.self, UserCollection.self, configurations: config)

    let tiers: [(String, Int, String)] = [
        ("bronze",    72, "BRZ"),
        ("silver",    78, "SLV"),
        ("gold",      85, "GLD"),
        ("legendary", 91, "LEG"),
    ]
    let ratings = tiers.map { (rarity, ovr, id) -> PlayerRating in
        let r = PlayerRating(stickerID: id, overall: ovr, rarity: rarity, confidence: "exact")
        container.mainContext.insert(r)
        return r
    }

    return ZStack {
        Color(hex: "1E1108").ignoresSafeArea()
        VStack(spacing: 32) {
            // Small badges (OVR strip context)
            HStack(spacing: 16) {
                ForEach(ratings, id: \.stickerID) { r in
                    RarityBadge(rating: r, iconSize: 12)
                }
            }

            // Medium icons
            HStack(spacing: 24) {
                ForEach(ratings, id: \.stickerID) { r in
                    RarityIcon(rarity: r.rarity, size: 28)
                }
            }

            // Large icons (reveals detail + legendary halo)
            HStack(spacing: 32) {
                ForEach(ratings, id: \.stickerID) { r in
                    RarityIcon(rarity: r.rarity, size: 64)
                }
            }
        }
        .padding()
    }
    .modelContainer(container)
}
