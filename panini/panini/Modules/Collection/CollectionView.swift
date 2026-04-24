import SwiftUI

// MARK: - CollectionView

struct CollectionView: View {
    @Environment(\.theme) private var theme
    @State private var mode: CollectionMode = .album

    enum CollectionMode: String, CaseIterable {
        case album = "Album"
        case grid  = "Grid"
    }

    var body: some View {
        Group {
            switch mode {
            case .album: AlbumView()
            case .grid:  GridView()
            }
        }
        .background(theme.bg)
        .navigationTitle(mode == .album ? "Album" : "Collection")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Sticker.self) { StickerDetailView(sticker: $0) }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("View", selection: $mode) {
                    ForEach(CollectionMode.allCases, id: \.self) { m in
                        Label(m.rawValue, systemImage: m == .album ? "book.pages" : "square.grid.2x2")
                            .tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }
}
