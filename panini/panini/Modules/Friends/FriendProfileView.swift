import SwiftUI

/// Profile screen for a single friend.
struct FriendProfileView: View {
    let friendship: Friendship
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text(friendship.friendUsername)
                .displayStyle(size: 32)
                .foregroundStyle(theme.ink)

            Text("@\(friendship.friendHandle)")
                .monoStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
