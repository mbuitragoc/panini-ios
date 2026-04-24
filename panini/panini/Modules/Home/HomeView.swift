import SwiftUI
import SwiftData

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.router) private var router

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @Query(sort: \UserCollection.updatedAt, order: .reverse)
    private var allCollections: [UserCollection]

    @State private var selectedTeam: String? = nil

    // MARK: - Derived stats

    private var ownedCount: Int {
        allStickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count
    }
    private var missingCount: Int { allStickers.count - ownedCount }
    private var dupesCount: Int {
        allStickers.reduce(0) { $0 + max(0, ($1.collection?.quantityOwned ?? 0) - 1) }
    }

    private var recentAdds: [Sticker] {
        allCollections
            .filter { $0.quantityOwned > 0 && $0.firstAcquiredAt != nil }
            .prefix(5)
            .compactMap { uc in allStickers.first { $0.id == uc.stickerID } }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                statsStrip
                scanCTA
                if !recentAdds.isEmpty { recentAddsSection }
                nationsSection
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(theme.bg)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Sticker.self) { StickerDetailView(sticker: $0) }
        .navigationDestination(item: $selectedTeam) { TeamAlbumView(countryCode: $0) }
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatCell(value: ownedCount,  label: "Owned",   color: theme.success)
            Rectangle().fill(theme.chip).frame(width: 1, height: 40)
            StatCell(value: missingCount, label: "Missing", color: theme.inkMuted)
            Rectangle().fill(theme.chip).frame(width: 1, height: 40)
            StatCell(value: dupesCount,  label: "Dupes",   color: theme.primary)
        }
        .padding(.vertical, 14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: - Scan CTA

    private var scanCTA: some View {
        Button { router.selectedTab = .scan } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.primaryInk)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a sticker")
                        .bodyStyle(size: 17, weight: .semibold)
                        .foregroundStyle(theme.primaryInk)
                    Text("Point at the back of your card")
                        .bodyStyle(size: 13)
                        .foregroundStyle(theme.primaryInk.opacity(0.75))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryInk.opacity(0.75))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Recent adds

    private var recentAddsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently added")
                .displayStyle(size: 20)
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentAdds, id: \.id) { sticker in
                        NavigationLink(value: sticker) {
                            StickerCard(sticker: sticker, collection: sticker.collection, width: 100)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Nations grid

    private var nationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All nations")
                .displayStyle(size: 20)
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)

            NationsGrid(
                collections: allCollections,
                stickers: allStickers,
                onTapTeam: { selectedTeam = $0 }
            )
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - StatCell

private struct StatCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .displayStyle(size: 26)
                .foregroundStyle(color)
            Text(label)
                .bodyStyle(size: 12)
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}
