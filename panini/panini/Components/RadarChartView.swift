import SwiftUI

// MARK: - RadarChartView

/// Six-axis hexagonal radar chart drawn with SwiftUI Canvas.
/// Axes start at the top and go clockwise.
/// For outfield players: PAC, SHO, PAS, DRI, DEF, PHY
/// For goalkeepers:      DIV, HAN, KIC, REF, SPD, POS
struct RadarChartView: View {
    struct Stat {
        let label: String
        let value: Int
    }

    let stats: [Stat]   // exactly 6
    let accentColor: Color
    var chartSize: CGFloat = 240

    var body: some View {
        ZStack {
            Canvas { ctx, _ in
                let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
                let radius = chartSize * 0.30
                drawGrid(ctx: ctx, center: center, radius: radius)
                drawFill(ctx: ctx, center: center, radius: radius)
            }
            .frame(width: chartSize, height: chartSize)

            ForEach(0..<min(stats.count, 6), id: \.self) { i in
                statLabel(stats[i], index: i)
            }
        }
        .frame(width: chartSize, height: chartSize)
    }

    // MARK: - Geometry helpers

    private func vertex(center: CGPoint, radius: CGFloat, index: Int, scale: CGFloat = 1) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3
        return CGPoint(
            x: center.x + radius * scale * cos(angle),
            y: center.y + radius * scale * sin(angle)
        )
    }

    // MARK: - Canvas drawing

    private func drawGrid(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let dim = Color.white.opacity(0.13)
        for fraction in [0.33, 0.66, 1.0] as [CGFloat] {
            var path = Path()
            for i in 0..<6 {
                let v = vertex(center: center, radius: radius, index: i, scale: fraction)
                if i == 0 { path.move(to: v) } else { path.addLine(to: v) }
            }
            path.closeSubpath()
            ctx.stroke(path, with: .color(dim), lineWidth: 1)
        }
        for i in 0..<6 {
            var path = Path()
            path.move(to: center)
            path.addLine(to: vertex(center: center, radius: radius, index: i))
            ctx.stroke(path, with: .color(dim), lineWidth: 1)
        }
    }

    private func drawFill(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard stats.count == 6 else { return }
        var path = Path()
        for (i, stat) in stats.enumerated() {
            let scale = CGFloat(max(1, stat.value)) / 99.0
            let v = vertex(center: center, radius: radius, index: i, scale: scale)
            if i == 0 { path.move(to: v) } else { path.addLine(to: v) }
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(accentColor.opacity(0.35)))
        ctx.stroke(path, with: .color(accentColor), lineWidth: 2.5)

        for (i, stat) in stats.enumerated() {
            let scale = CGFloat(max(1, stat.value)) / 99.0
            let v = vertex(center: center, radius: radius, index: i, scale: scale)
            let r: CGFloat = 3.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: v.x - r, y: v.y - r, width: r * 2, height: r * 2)),
                with: .color(accentColor)
            )
        }
    }

    // MARK: - Stat labels

    @ViewBuilder
    private func statLabel(_ stat: Stat, index: Int) -> some View {
        let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
        let innerRadius = chartSize * 0.30
        let labelRadius = innerRadius + chartSize * 0.145
        let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3

        VStack(spacing: 1) {
            Text(stat.label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(stat.value)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .position(
            x: center.x + labelRadius * cos(angle),
            y: center.y + labelRadius * sin(angle)
        )
    }
}

// MARK: - Rarity color

extension PlayerRating {
    var rarityColor: Color {
        switch rarity {
        case "legendary": return Color(hex: "FFD700")
        case "gold":      return Color(hex: "E0A020")
        case "silver":    return Color(hex: "B8B8B8")
        default:          return Color(hex: "CD7F32")
        }
    }

    var outfieldStats: [RadarChartView.Stat] {
        [
            .init(label: "PAC", value: pace),
            .init(label: "SHO", value: shooting),
            .init(label: "PAS", value: passing),
            .init(label: "DRI", value: dribbling),
            .init(label: "DEF", value: defending),
            .init(label: "PHY", value: physical),
        ]
    }

    var gkStats: [RadarChartView.Stat] {
        [
            .init(label: "DIV", value: gkDiving),
            .init(label: "HAN", value: gkHandling),
            .init(label: "KIC", value: gkKicking),
            .init(label: "REF", value: gkReflexes),
            .init(label: "SPD", value: gkSpeed),
            .init(label: "POS", value: gkPositioning),
        ]
    }

    var radarStats: [RadarChartView.Stat] {
        isGK ? gkStats : outfieldStats
    }
}
