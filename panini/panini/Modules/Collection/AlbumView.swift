import SwiftUI
import SwiftData

// MARK: - AlbumTeamData

private struct AlbumTeamData: Identifiable {
    let id: String        // countryCode
    let name: String
    let stickers: [Sticker]
}

// MARK: - AlbumView

struct AlbumView: View {
    @Environment(\.theme) private var theme

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    private var teams: [AlbumTeamData] {
        var seen = Set<String>()
        let unique = allStickers.filter { seen.insert($0.id).inserted }
        return Dictionary(grouping: unique, by: \.countryCode)
            .map { code, stickers in
                AlbumTeamData(id: code, name: stickers.first?.nationalTeam ?? code, stickers: stickers)
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        if teams.isEmpty {
            emptyState
        } else {
            TabView {
                ForEach(teams) { team in
                    TeamSpread(team: team)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(theme.inkMuted)
            Text("Loading sticker data…")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TeamSpread

private struct TeamSpread: View {
    let team: AlbumTeamData

    @Environment(\.theme) private var theme

    private var ownedCount: Int { team.stickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count }
    private var total: Int { team.stickers.count }
    private var completionPct: Int { total > 0 ? (ownedCount * 100) / total : 0 }

    private let hPad: CGFloat = 16
    private let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let cardWidth = max(60, (geo.size.width - hPad * 2 - spacing * 3) / 4)

            ZStack(alignment: .top) {
                // Center binding line — stays fixed while content scrolls beneath
                Rectangle()
                    .fill(Color(hex: "9A8472").opacity(0.22))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 16) {
                        teamHeader

                        let cols = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: 4)
                        LazyVGrid(columns: cols, spacing: spacing) {
                            ForEach(team.stickers, id: \.id) { sticker in
                                NavigationLink(value: sticker) {
                                    StickerCard(
                                        sticker: sticker,
                                        collection: sticker.collection,
                                        width: cardWidth
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, hPad)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    private var teamHeader: some View {
        VStack(spacing: 8) {
            flagChip
            Text(team.name)
                .displayStyle(size: 20)
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Text("\(completionPct)% complete · \(ownedCount)/\(total)")
                .bodyStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var flagChip: some View {
        let colors = teamGradient(for: team.id)
        return Text(team.id)
            .monoStyle(size: 11)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
    }
}

// MARK: - TeamAlbumView

/// Single-team album page pushed from HomeView's nations grid tap.
struct TeamAlbumView: View {
    let countryCode: String

    @Environment(\.theme) private var theme

    @Query private var stickers: [Sticker]

    init(countryCode: String) {
        self.countryCode = countryCode
        _stickers = Query(
            filter: #Predicate<Sticker> { $0.countryCode == countryCode },
            sort: [SortDescriptor(\.stickerNumber)]
        )
    }

    private var uniqueStickers: [Sticker] {
        var seen = Set<String>()
        return stickers.filter { seen.insert($0.id).inserted }
    }
    private var teamName: String { stickers.first?.nationalTeam ?? countryCode }
    private var ownedCount: Int { uniqueStickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count }
    private var completionPct: Int {
        uniqueStickers.isEmpty ? 0 : (ownedCount * 100) / uniqueStickers.count
    }

    private let hPad: CGFloat = 16
    private let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let cardWidth = max(60, (geo.size.width - hPad * 2 - spacing * 3) / 4)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color(hex: "9A8472").opacity(0.22))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 16) {
                        teamHeader

                        let cols = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: 4)
                        LazyVGrid(columns: cols, spacing: spacing) {
                            ForEach(uniqueStickers, id: \.id) { sticker in
                                NavigationLink(value: sticker) {
                                    StickerCard(
                                        sticker: sticker,
                                        collection: sticker.collection,
                                        width: cardWidth
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, hPad)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .background(theme.bg)
        .navigationTitle(teamName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var teamHeader: some View {
        VStack(spacing: 8) {
            let colors = teamGradient(for: countryCode)
            Text(countryCode)
                .monoStyle(size: 11)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
            Text(teamName)
                .displayStyle(size: 20)
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Text("\(completionPct)% complete · \(ownedCount)/\(uniqueStickers.count)")
                .bodyStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}
