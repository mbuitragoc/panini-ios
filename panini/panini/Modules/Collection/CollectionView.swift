import SwiftUI

/// Collection screen with Album / Grid segment toggle.
struct CollectionView: View {
    @Environment(\.theme) private var theme
    @State private var selectedSegment: CollectionSegment = .album

    enum CollectionSegment: String, CaseIterable {
        case album = "Album"
        case grid = "Grid"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedSegment) {
                ForEach(CollectionSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedSegment {
            case .album:
                AlbumView()
            case .grid:
                GridView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CollectionView()
    }
}
