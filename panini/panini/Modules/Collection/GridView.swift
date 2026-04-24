import SwiftUI

/// Grid layout for the collection — placeholder pending slice #8.
struct GridView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("Grid view coming in slice #8")
            .bodyStyle(size: 15)
            .foregroundStyle(theme.inkMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GridView()
}
