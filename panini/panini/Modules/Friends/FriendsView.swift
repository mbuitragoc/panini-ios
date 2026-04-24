import SwiftUI

/// Friends list screen — placeholder.
struct FriendsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text("Friends")
                .displayStyle(size: 40)
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
}
