import SwiftUI

/// Album layout for the collection — placeholder pending slice #8.
struct AlbumView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("Album view coming in slice #8")
            .bodyStyle(size: 15)
            .foregroundStyle(theme.inkMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AlbumView()
}
