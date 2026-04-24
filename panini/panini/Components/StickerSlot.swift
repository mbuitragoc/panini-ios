import SwiftUI

/// Empty album slot shown for stickers the user has not yet acquired.
struct StickerSlot: View {
    let sticker: Sticker
    var width: CGFloat = 66

    private var height: CGFloat { width * 1.4 }
    private var cornerRadius: CGFloat { width * 0.07 }

    var body: some View {
        ZStack {
            // Dashed border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    Color(hex: "9A8472").opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                )
                .frame(width: width, height: height)

            // 45-degree diagonal hatching pattern
            DiagonalHatch(spacing: 8, lineWidth: 0.5, color: Color(hex: "9A8472").opacity(0.2))
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Sticker ID label
            Text(sticker.id)
                .monoStyle(size: max(7, width * 0.11))
                .foregroundStyle(Color(hex: "9A8472").opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(4)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - DiagonalHatch

/// A Canvas-drawn 45-degree diagonal line pattern.
private struct DiagonalHatch: View {
    let spacing: CGFloat
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let count = Int((size.width + size.height) / spacing) + 2
            for i in 0 ... count {
                let offset = CGFloat(i) * spacing
                path.move(to: CGPoint(x: offset - size.height, y: 0))
                path.addLine(to: CGPoint(x: offset, y: size.height))
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

#Preview {
    let sticker = Sticker(
        id: "FRA-20",
        countryCode: "FRA",
        stickerNumber: 20,
        type: "player",
        nationalTeam: "France"
    )
    return HStack(spacing: 16) {
        StickerSlot(sticker: sticker, width: 66)
        StickerSlot(sticker: sticker, width: 88)
        StickerSlot(sticker: sticker, width: 110)
    }
    .padding()
}
