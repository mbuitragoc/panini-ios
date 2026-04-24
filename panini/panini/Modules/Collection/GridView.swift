import SwiftUI
import SwiftData

// MARK: - StatusFilter

private enum StatusFilter: String, CaseIterable {
    case all         = "All"
    case owned       = "Owned"
    case missing     = "Missing"
    case duplicates  = "Dupes"
    case wishlisted  = "Wishlist"
    case blacklisted = "Blacklist"
}

// MARK: - GridView

struct GridView: View {
    @Environment(\.theme) private var theme

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @State private var statusFilter: StatusFilter = .all
    @State private var selectedPositions: Set<String> = []

    private let positions = ["GK", "DEF", "MID", "FWD"]
    private let hPad: CGFloat = 12
    private let spacing: CGFloat = 6

    // MARK: - Filtering

    private var filtered: [Sticker] {
        var seen = Set<String>()
        return allStickers.filter { s in
            guard seen.insert(s.id).inserted else { return false }
            let statusOK: Bool = {
                switch statusFilter {
                case .all:         return true
                case .owned:       return (s.collection?.quantityOwned ?? 0) > 0
                case .missing:     return (s.collection?.quantityOwned ?? 0) == 0
                case .duplicates:  return (s.collection?.quantityOwned ?? 0) > 1
                case .wishlisted:  return s.collection?.wishlisted == true
                case .blacklisted: return s.collection?.blacklisted == true
                }
            }()
            let posOK = selectedPositions.isEmpty || selectedPositions.contains(s.position ?? "")
            return statusOK && posOK
        }
    }

    private var hasActiveFilters: Bool {
        statusFilter != .all || !selectedPositions.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if !selectedPositions.isEmpty {
                activeFilterChips
            }
            Divider()
            grid
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatusFilter.allCases, id: \.self) { f in
                    FilterChip(
                        title: f.rawValue,
                        isActive: statusFilter == f
                    ) {
                        statusFilter = f
                    }
                }

                Rectangle()
                    .fill(theme.inkMuted.opacity(0.3))
                    .frame(width: 1, height: 20)

                ForEach(positions, id: \.self) { pos in
                    FilterChip(
                        title: pos,
                        isActive: selectedPositions.contains(pos)
                    ) {
                        if selectedPositions.contains(pos) {
                            selectedPositions.remove(pos)
                        } else {
                            selectedPositions.insert(pos)
                        }
                    }
                }

                if hasActiveFilters {
                    Button {
                        statusFilter = .all
                        selectedPositions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .animation(.easeInOut(duration: 0.2), value: hasActiveFilters)
    }

    // MARK: - Active position chips (dismissible)

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(selectedPositions).sorted(), id: \.self) { pos in
                    Button {
                        selectedPositions.remove(pos)
                    } label: {
                        HStack(spacing: 4) {
                            Text(pos)
                                .bodyStyle(size: 12, weight: .medium)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(theme.primaryInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.primary, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPositions)
    }

    // MARK: - Grid

    private var grid: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - hPad * 2 - spacing * 3) / 4
            let cols = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: 4)

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: spacing) {
                        ForEach(filtered, id: \.id) { sticker in
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
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(theme.inkMuted)
            Text("No stickers match these filters")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyStyle(size: 13, weight: isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? theme.primaryInk : theme.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isActive ? theme.primary : theme.chip,
                    in: Capsule()
                )
        }
    }
}
