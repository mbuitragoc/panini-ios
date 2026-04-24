import SwiftUI

// MARK: - Team colour palette

let teamGradients: [String: [Color]] = [
    "ARG": [Color(hex: "74ACDF"), Color(hex: "FFFFFF")],
    "AUS": [Color(hex: "00843D"), Color(hex: "FFCD00")],
    "BEL": [Color(hex: "EF3340"), Color(hex: "000000")],
    "BRA": [Color(hex: "009C3B"), Color(hex: "FFDF00")],
    "CMR": [Color(hex: "007A5E"), Color(hex: "CE1126")],
    "CAN": [Color(hex: "FF0000"), Color(hex: "FFFFFF")],
    "CHI": [Color(hex: "D52B1E"), Color(hex: "003087")],
    "COL": [Color(hex: "FCD116"), Color(hex: "003087")],
    "CRC": [Color(hex: "002B7F"), Color(hex: "CE1126")],
    "CRO": [Color(hex: "FF0000"), Color(hex: "FFFFFF")],
    "CZE": [Color(hex: "D7141A"), Color(hex: "11457E")],
    "DEN": [Color(hex: "C60C30"), Color(hex: "FFFFFF")],
    "ECU": [Color(hex: "FFD100"), Color(hex: "003580")],
    "EGY": [Color(hex: "CE1126"), Color(hex: "000000")],
    "ENG": [Color(hex: "CF081F"), Color(hex: "FFFFFF")],
    "FRA": [Color(hex: "002395"), Color(hex: "ED2939")],
    "GER": [Color(hex: "000000"), Color(hex: "DD0000")],
    "GHA": [Color(hex: "006B3F"), Color(hex: "FCD116")],
    "GRE": [Color(hex: "0D5EAF"), Color(hex: "FFFFFF")],
    "HON": [Color(hex: "0073CF"), Color(hex: "FFFFFF")],
    "HUN": [Color(hex: "CE2939"), Color(hex: "477050")],
    "IRN": [Color(hex: "239F40"), Color(hex: "DA0000")],
    "JPN": [Color(hex: "003087"), Color(hex: "BC002D")],
    "KOR": [Color(hex: "CD2E3A"), Color(hex: "003478")],
    "MAR": [Color(hex: "C1272D"), Color(hex: "006233")],
    "MEX": [Color(hex: "006847"), Color(hex: "CE1126")],
    "NED": [Color(hex: "FF4F00"), Color(hex: "FFFFFF")],
    "NGA": [Color(hex: "008751"), Color(hex: "FFFFFF")],
    "NZL": [Color(hex: "00247D"), Color(hex: "CC142B")],
    "PAN": [Color(hex: "DA121A"), Color(hex: "0033A0")],
    "PAR": [Color(hex: "D52B1E"), Color(hex: "0038A8")],
    "PER": [Color(hex: "D91023"), Color(hex: "FFFFFF")],
    "POL": [Color(hex: "FFFFFF"), Color(hex: "DC143C")],
    "POR": [Color(hex: "006600"), Color(hex: "FF0000")],
    "QAT": [Color(hex: "8D153A"), Color(hex: "FFFFFF")],
    "ROU": [Color(hex: "002B7F"), Color(hex: "FCD116")],
    "SAU": [Color(hex: "006C35"), Color(hex: "FFFFFF")],
    "SEN": [Color(hex: "00853F"), Color(hex: "FDEF42")],
    "SRB": [Color(hex: "C6363C"), Color(hex: "0C4076")],
    "SVK": [Color(hex: "FFFFFF"), Color(hex: "0B4EA2")],
    "SLO": [Color(hex: "003DA5"), Color(hex: "FF0000")],
    "ESP": [Color(hex: "AA151B"), Color(hex: "F1BF00")],
    "TUN": [Color(hex: "E70013"), Color(hex: "FFFFFF")],
    "URU": [Color(hex: "5EB6E4"), Color(hex: "FFFFFF")],
    "USA": [Color(hex: "002868"), Color(hex: "BF0A30")],
    "UZB": [Color(hex: "1EB53A"), Color(hex: "0099B5")],
    "WAL": [Color(hex: "00AB39"), Color(hex: "C8102E")],
    "ZIM": [Color(hex: "006400"), Color(hex: "FFD200")]
]

func teamGradient(for code: String) -> [Color] {
    teamGradients[code] ?? [Color(hex: "6B6B6B"), Color(hex: "3A3A3A")]
}

// MARK: - PortraitPlaceholder

private struct PortraitPlaceholder: View {
    let countryCode: String
    let width: CGFloat

    private var height: CGFloat { width }
    private var colors: [Color] { teamGradient(for: countryCode) }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            // Diagonal stripe overlay
            DiagonalStripes(color: .white.opacity(0.07), spacing: max(6, width * 0.1), lineWidth: max(3, width * 0.05))

            Text("[player portrait]")
                .monoStyle(size: max(6, width * 0.09))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: width, height: height)
    }
}

private struct DiagonalStripes: View {
    let color: Color
    let spacing: CGFloat
    let lineWidth: CGFloat

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

// MARK: - StickerCard

/// The hero sticker card component. Full visual implementation.
struct StickerCard: View {
    let sticker: Sticker
    var collection: UserCollection?
    var width: CGFloat = 110
    var revealed: Bool = false

    private var scale: CGFloat { width / 110 }
    private var height: CGFloat { width * 1.4 }
    private var frameRadius: CGFloat { 4 * scale }
    private var outerFrameColor: Color { Color(hex: "1A1A1A") }
    private var isMissing: Bool {
        collection == nil || (collection?.quantityOwned ?? 0) == 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardBody
                .grayscale(isMissing ? 1 : 0)
                .opacity(isMissing ? 0.55 : 1)

            if isMissing {
                missingOverlay
            }

            if let qty = collection?.quantityOwned, qty > 1, !isMissing {
                duplicateBadge(qty)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: Card body

    @ViewBuilder
    private var cardBody: some View {
        ZStack(alignment: .topLeading) {
            // Outer dark frame
            RoundedRectangle(cornerRadius: frameRadius)
                .fill(outerFrameColor)
                .shadow(color: .black.opacity(0.35), radius: 4 * scale, x: 0, y: 2 * scale)

            // Inner window — team gradient
            let innerPadding = 3.0 * scale
            let innerRadius = max(2, frameRadius - 1)
            let colors = teamGradient(for: sticker.countryCode)

            ZStack(alignment: .bottom) {
                // Team gradient background
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: innerRadius))

                // Portrait area
                PortraitPlaceholder(countryCode: sticker.countryCode, width: width - innerPadding * 2)
                    .clipShape(RoundedRectangle(cornerRadius: innerRadius))

                // Bottom name plate gradient overlay
                namePlate
            }
            .padding(innerPadding)

            // Number badge — top left
            numberBadge

            // ID badge — top right
            idBadge
        }
    }

    // MARK: Name plate

    @ViewBuilder
    private var namePlate: some View {
        VStack(spacing: 1) {
            if let name = sticker.playerName {
                Text(name.uppercased())
                    .displayStyle(size: 11 * scale)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if let pos = sticker.position {
                Text(pos)
                    .bodyStyle(size: 7.5 * scale, weight: .medium)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 4 * scale)
        .padding(.vertical, 5 * scale)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: max(2, frameRadius - 1),
                bottomTrailingRadius: max(2, frameRadius - 1),
                topTrailingRadius: 0
            )
        )
    }

    // MARK: Number badge

    @ViewBuilder
    private var numberBadge: some View {
        Text("\(sticker.stickerNumber)")
            .displayStyle(size: 22 * scale)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2 * scale)
            .padding(.leading, 6 * scale)
            .padding(.top, 4 * scale)
    }

    // MARK: ID badge

    @ViewBuilder
    private var idBadge: some View {
        HStack {
            Spacer()
            Text(sticker.id)
                .monoStyle(size: 7 * scale)
                .foregroundStyle(.white)
                .padding(.horizontal, 4 * scale)
                .padding(.vertical, 2 * scale)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(.trailing, 5 * scale)
                .padding(.top, 6 * scale)
        }
    }

    // MARK: Missing overlay

    @ViewBuilder
    private var missingOverlay: some View {
        ZStack {
            Color.black.opacity(0.08)
                .clipShape(RoundedRectangle(cornerRadius: frameRadius))

            Text("—")
                .displayStyle(size: 28 * scale)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: Duplicate badge

    @ViewBuilder
    private func duplicateBadge(_ qty: Int) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("×\(qty)")
                    .monoStyle(size: 9 * scale)
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .padding(.horizontal, 5 * scale)
                    .padding(.vertical, 2 * scale)
                    .background(Color(hex: "FFD700"))
                    .clipShape(Capsule())
                    .padding(.trailing, 5 * scale)
                    .padding(.bottom, 5 * scale)
            }
        }
    }
}

// MARK: - Preview

#Preview("Sticker cards") {
    let owned = UserCollection(userID: "u1", stickerID: "FRA-20", quantityOwned: 1)
    let dupe = UserCollection(userID: "u1", stickerID: "BRA-7", quantityOwned: 3)

    let fra = Sticker(id: "FRA-20", countryCode: "FRA", stickerNumber: 20, type: "player",
                      playerName: "K. Mbappé", position: "FWD", nationalTeam: "France")
    let bra = Sticker(id: "BRA-7", countryCode: "BRA", stickerNumber: 7, type: "player",
                      playerName: "Vinicius Jr", position: "FWD", nationalTeam: "Brazil")
    let missing = Sticker(id: "ARG-10", countryCode: "ARG", stickerNumber: 10, type: "player",
                          playerName: "L. Messi", position: "FWD", nationalTeam: "Argentina")

    return HStack(spacing: 12) {
        StickerCard(sticker: fra, collection: owned)
        StickerCard(sticker: bra, collection: dupe)
        StickerCard(sticker: missing, collection: nil)
    }
    .padding()
    .background(Color(hex: "F7EFE1"))
}
