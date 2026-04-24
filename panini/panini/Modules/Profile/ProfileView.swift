import SwiftUI

/// Profile screen with stub leaderboard list.
struct ProfileView: View {
    @Environment(\.theme) private var theme

    private let stubLeaderboard = [
        ("mbuitragoc", 412),
        ("collector99", 398),
        ("stickerking", 375),
        ("worldcupfan", 350),
        ("panini_pro", 340)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Profile")
                    .displayStyle(size: 40)
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard")
                        .bodyStyle(size: 13, weight: .semibold)
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal)
                        .textCase(.uppercase)

                    ForEach(Array(stubLeaderboard.enumerated()), id: \.offset) { index, entry in
                        leaderboardRow(rank: index + 1, handle: entry.0, count: entry.1)
                    }
                }
            }
            .padding(.top)
        }
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func leaderboardRow(rank: Int, handle: String, count: Int) -> some View {
        HStack {
            Text("\(rank)")
                .monoStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
                .frame(width: 24)

            Text(handle)
                .bodyStyle(size: 15)
                .foregroundStyle(theme.ink)

            Spacer()

            Text("\(count)")
                .monoStyle(size: 13)
                .foregroundStyle(theme.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
