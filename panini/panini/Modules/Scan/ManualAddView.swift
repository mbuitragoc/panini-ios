import SwiftUI
import SwiftData

// MARK: - ManualAddView

/// Search the sticker checklist by ID, player name, country, or position.
/// Tapping a result opens ScanConfirmView with the same reveal/duplicate logic as the scan flow.
struct ManualAddView: View {
    @Environment(\.theme) private var theme
    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @State private var query     = ""
    @State private var selectedID: String? = nil

    // MARK: - Filtering

    private var results: [Sticker] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return allStickers.filter {
            $0.id.lowercased().contains(q)
            || ($0.playerName?.lowercased().contains(q) ?? false)
            || $0.nationalTeam.lowercased().contains(q)
            || $0.countryCode.lowercased().hasPrefix(q)
            || ($0.position?.lowercased() == q)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    emptyPrompt
                } else if results.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "FRA-20, Mbappé, Spain, GK…")
            .background(theme.bg)
            .navigationTitle("Find a sticker")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedID) { id in
                ScanConfirmView(stickerID: id)
            }
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        List(results, id: \.id) { sticker in
            Button { selectedID = sticker.id } label: {
                StickerRow(sticker: sticker)
            }
            .listRowBackground(theme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty states

    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(theme.inkMuted)
            Text("Search by sticker ID, player name,\ncountry, or position")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(theme.inkMuted)
            Text("No stickers match \"\(query)\"")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - StickerRow

private struct StickerRow: View {
    let sticker: Sticker
    @Environment(\.theme) private var theme

    private let previewCollection = UserCollection(userID: "", stickerID: "", quantityOwned: 1)

    var body: some View {
        HStack(spacing: 14) {
            StickerCard(sticker: sticker, collection: previewCollection, width: 60)

            VStack(alignment: .leading, spacing: 3) {
                if let name = sticker.playerName {
                    Text(name)
                        .bodyStyle(size: 15, weight: .medium)
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(sticker.nationalTeam)
                        .bodyStyle(size: 13)
                        .foregroundStyle(theme.inkSoft)

                    if let pos = sticker.position {
                        Text("·").foregroundStyle(theme.inkMuted)
                        Text(pos)
                            .bodyStyle(size: 13)
                            .foregroundStyle(theme.inkMuted)
                    }
                }

                Text(sticker.id)
                    .monoStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.vertical, 6)
    }
}
