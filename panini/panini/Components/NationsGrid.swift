import SwiftUI

// MARK: - World Cup 2026 nations

private let wc2026Nations: [String] = [
    "ARG", "AUS", "BEL", "BRA", "CMR", "CAN", "CHI", "COL",
    "CRC", "CRO", "CZE", "DEN", "ECU", "EGY", "ENG", "FRA",
    "GER", "GHA", "GRE", "HON", "HUN", "IRN", "JPN", "KOR",
    "MAR", "MEX", "NED", "NGA", "NZL", "PAN", "PAR", "PER",
    "POL", "POR", "QAT", "ROU", "SAU", "SEN", "SRB", "SVK",
    "SLO", "ESP", "TUN", "URU", "USA", "UZB", "WAL", "ZIM"
]

// MARK: - NationsGrid

/// A lazy grid of all 48 World Cup 2026 national team tiles.
/// Each tile shows the country code and a completion percentage fill bar.
struct NationsGrid: View {
    let collections: [UserCollection]
    let stickers: [Sticker]
    let onTapTeam: (String) -> Void

    @Environment(\.theme) private var theme

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(wc2026Nations, id: \.self) { code in
                NationTile(
                    code: code,
                    completion: completionRatio(for: code),
                    theme: theme
                )
                .onTapGesture { onTapTeam(code) }
            }
        }
    }

    // MARK: Completion calculation

    private func completionRatio(for countryCode: String) -> Double {
        let teamStickers = stickers.filter { $0.countryCode == countryCode }
        guard !teamStickers.isEmpty else { return 0 }
        let ownedIDs = Set(
            collections
                .filter { $0.quantityOwned > 0 }
                .map(\.stickerID)
        )
        let owned = teamStickers.filter { ownedIDs.contains($0.id) }.count
        return Double(owned) / Double(teamStickers.count)
    }
}

// MARK: - NationTile

private struct NationTile: View {
    let code: String
    let completion: Double
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            Text(code)
                .monoStyle(size: 12)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Completion fill bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.chip)

                    Capsule()
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * completion))
                }
            }
            .frame(height: 4)

            Text(percentText)
                .monoStyle(size: 9)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.chip, lineWidth: 1)
        }
    }

    private var barColor: Color {
        switch completion {
        case 1.0: theme.success
        case 0.6...: theme.primary
        default: theme.accent.opacity(0.7)
        }
    }

    private var percentText: String {
        "\(Int(completion * 100))%"
    }
}

#Preview {
    ScrollView {
        NationsGrid(
            collections: [],
            stickers: [],
            onTapTeam: { _ in }
        )
        .padding()
    }
    .background(Color(hex: "F7EFE1"))
}
