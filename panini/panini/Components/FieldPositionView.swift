import SwiftUI

// MARK: - FieldPositionView

/// Bird's-eye half-field showing where a player lines up for their national team.
/// The team defends the bottom goal (GK near bottom, ST near top).
struct FieldPositionView: View {
    let position: String        // e.g. "ST", "CB", "GK"
    let jerseyNumber: Int?
    let accentColor: Color

    // Normalized (x,y) coords: (0,0) = top-left, team defends bottom goal
    private static let coords: [String: CGPoint] = [
        "GK":  .init(x: 0.50, y: 0.88),
        "CB":  .init(x: 0.50, y: 0.76),
        "LCB": .init(x: 0.33, y: 0.76),
        "RCB": .init(x: 0.67, y: 0.76),
        "LB":  .init(x: 0.17, y: 0.71),
        "RB":  .init(x: 0.83, y: 0.71),
        "LWB": .init(x: 0.10, y: 0.61),
        "RWB": .init(x: 0.90, y: 0.61),
        "CDM": .init(x: 0.50, y: 0.56),
        "CM":  .init(x: 0.50, y: 0.50),
        "LM":  .init(x: 0.15, y: 0.50),
        "RM":  .init(x: 0.85, y: 0.50),
        "CAM": .init(x: 0.50, y: 0.42),
        "LW":  .init(x: 0.11, y: 0.28),
        "RW":  .init(x: 0.89, y: 0.28),
        "CF":  .init(x: 0.50, y: 0.22),
        "LS":  .init(x: 0.35, y: 0.19),
        "RS":  .init(x: 0.65, y: 0.19),
        "ST":  .init(x: 0.50, y: 0.17),
    ]

    var body: some View {
        Canvas { ctx, size in
            drawField(ctx: ctx, size: size)
            if let coord = Self.coords[position] {
                drawDot(ctx: ctx, size: size, coord: coord)
            }
        }
        .overlay {
            if let coord = Self.coords[position] {
                GeometryReader { geo in
                    let x = coord.x * geo.size.width
                    let y = coord.y * geo.size.height
                    if let jersey = jerseyNumber {
                        Text("\(jersey)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawField(ctx: GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height
        let fieldColor = Color(hex: "2D8A4E")
        let line = Color.white.opacity(0.55)
        let lw: CGFloat = 1

        // Background
        var bg = Path()
        bg.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: W, height: H),
            cornerSize: CGSize(width: 6, height: 6)
        )
        ctx.fill(bg, with: .color(fieldColor))

        // Border
        var border = Path()
        border.addRoundedRect(
            in: CGRect(x: 1.5, y: 1.5, width: W - 3, height: H - 3),
            cornerSize: CGSize(width: 5, height: 5)
        )
        ctx.stroke(border, with: .color(line), lineWidth: lw)

        // Halfway line
        stroke(ctx, from: CGPoint(x: 2, y: H * 0.5), to: CGPoint(x: W - 2, y: H * 0.5),
               color: line, width: lw)

        // Center circle
        let cr = W * 0.17
        ctx.stroke(
            Path(ellipseIn: CGRect(x: W/2 - cr, y: H*0.5 - cr, width: cr*2, height: cr*2)),
            with: .color(line), lineWidth: lw
        )

        // Bottom penalty area (team's own end)
        let paW = W * 0.64, paH = H * 0.19
        ctx.stroke(
            Path(CGRect(x: (W - paW)/2, y: H - paH, width: paW, height: paH)),
            with: .color(line), lineWidth: lw
        )

        // Top penalty area (opponent end)
        ctx.stroke(
            Path(CGRect(x: (W - paW)/2, y: 0, width: paW, height: paH)),
            with: .color(line), lineWidth: lw
        )
    }

    private func drawDot(ctx: GraphicsContext, size: CGSize, coord: CGPoint) {
        let cx = coord.x * size.width
        let cy = coord.y * size.height
        let r: CGFloat = 11

        // Drop shadow
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - r + 1, y: cy - r + 2, width: r*2, height: r*2)),
            with: .color(.black.opacity(0.28))
        )
        // Colored fill
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2)),
            with: .color(accentColor)
        )
        // White ring
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2)),
            with: .color(.white), lineWidth: 1.5
        )
    }

    private func stroke(
        _ ctx: GraphicsContext,
        from: CGPoint, to: CGPoint,
        color: Color, width: CGFloat
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        ctx.stroke(path, with: .color(color), lineWidth: width)
    }
}
