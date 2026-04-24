import SwiftUI
import SwiftData

// MARK: - LeaderboardEntry

private struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let handle: String
    let ownedCount: Int
    let isMe: Bool
}

// MARK: - Badge

private struct Badge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let unlocked: Bool
    let progress: String?
}

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(\.theme) private var theme
    @Environment(\.router) private var router
    @Environment(AuthService.self) private var authService

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @Query(sort: \UserCollection.updatedAt, order: .reverse)
    private var allCollections: [UserCollection]

    @Query(filter: #Predicate<Friendship> { $0.status == "accepted" })
    private var acceptedFriendships: [Friendship]

    @Query(filter: #Predicate<Trade> { $0.status == "completed" })
    private var completedTrades: [Trade]

    // MARK: - Derived stats

    private var ownedCount: Int {
        allStickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count
    }
    private var missingCount: Int { allStickers.count - ownedCount }
    private var dupesCount: Int {
        allStickers.reduce(0) { $0 + max(0, ($1.collection?.quantityOwned ?? 0) - 1) }
    }

    // MARK: - Badges

    private var firstPackUnlocked: Bool {
        allCollections.contains { $0.quantityOwned >= 1 }
    }

    private var firstCompleteTeamUnlocked: Bool {
        let byCountry = Dictionary(grouping: allStickers, by: \.countryCode)
        return byCountry.values.contains { group in
            !group.isEmpty && group.allSatisfy { ($0.collection?.quantityOwned ?? 0) > 0 }
        }
    }

    private var legendStickers: [Sticker] { allStickers.filter { $0.type == "legend" } }
    private var legendsOwned: Int { legendStickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count }

    private var badges: [Badge] {[
        Badge(id: "first_pack", icon: "shippingbox.fill",
              title: "First pack", unlocked: firstPackUnlocked, progress: nil),
        Badge(id: "complete_team", icon: "flag.fill",
              title: "First complete team", unlocked: firstCompleteTeamUnlocked, progress: nil),
        Badge(id: "ten_trades", icon: "arrow.left.arrow.right.circle.fill",
              title: "10 trades",
              unlocked: completedTrades.count >= 10,
              progress: completedTrades.count < 10 ? "\(completedTrades.count) / 10" : nil),
        Badge(id: "all_legends", icon: "star.fill",
              title: "All legends",
              unlocked: !legendStickers.isEmpty && legendsOwned == legendStickers.count,
              progress: legendStickers.isEmpty ? nil : "\(legendsOwned) / \(legendStickers.count)"),
    ]}

    // MARK: - Leaderboard

    private var leaderboard: [(rank: Int, entry: LeaderboardEntry)] {
        let me = LeaderboardEntry(
            id: authService.currentUserID ?? "me",
            name: (authService.currentUser?.username.isEmpty == false)
                ? authService.currentUser!.username
                : (authService.currentUser?.handle ?? "You"),
            handle: authService.currentUser?.handle ?? "you",
            ownedCount: ownedCount,
            isMe: true
        )
        let friends = acceptedFriendships.map {
            LeaderboardEntry(id: $0.friendID,
                             name: $0.friendUsername.isEmpty ? $0.friendHandle : $0.friendUsername,
                             handle: $0.friendHandle,
                             ownedCount: $0.friendOwnedCount,
                             isMe: false)
        }
        let sorted = ([me] + friends).sorted { $0.ownedCount > $1.ownedCount }

        var ranked: [(rank: Int, entry: LeaderboardEntry)] = []
        var prevCount = -1
        for (i, entry) in sorted.enumerated() {
            let rank = entry.ownedCount == prevCount ? ranked.last!.rank : i + 1
            ranked.append((rank: rank, entry: entry))
            prevCount = entry.ownedCount
        }
        return ranked
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                profileHeader
                statsStrip
                badgesSection
                leaderboardSection
                settingsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 20)
        }
        .background(theme.bg)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            let handle = authService.currentUser?.handle ?? "?"
            let initial = handle.first.map(String.init) ?? "?"

            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [theme.primary, Color(hex: "E8C22F"), Color(hex: "E8C22F"), theme.primary],
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 96, height: 96)

                Text(initial.uppercased())
                    .displayStyle(size: 36)
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Color(hex: "C8511B"), in: Circle())
            }

            VStack(spacing: 4) {
                if let name = authService.currentUser?.username, !name.isEmpty {
                    Text(name)
                        .displayStyle(size: 22)
                        .foregroundStyle(theme.ink)
                }
                Text("@\(authService.currentUser?.handle ?? "—")")
                    .monoStyle(size: 14)
                    .foregroundStyle(theme.inkMuted)
                if let joined = authService.currentUser?.joinedAt {
                    Text("Since \(joined.formatted(.dateTime.month(.wide).year()))")
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            ProfileStatCell(value: ownedCount,   label: "Owned",   color: theme.success)
            stripDivider
            ProfileStatCell(value: missingCount, label: "Missing", color: theme.inkMuted)
            stripDivider
            ProfileStatCell(value: dupesCount,   label: "Dupes",   color: theme.primary)
            stripDivider
            ProfileStatCell(value: acceptedFriendships.count, label: "Friends", color: Color(hex: "2196F3"))
        }
        .padding(.vertical, 14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var stripDivider: some View {
        Rectangle().fill(theme.chip).frame(width: 1, height: 36)
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Achievements")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badges) { BadgeCard(badge: $0) }
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Leaderboard")

            if leaderboard.count == 1 {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.inkMuted)
                    Text("Add friends to see the leaderboard")
                        .bodyStyle(size: 13)
                        .foregroundStyle(theme.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(leaderboard.enumerated()), id: \.offset) { i, item in
                        if i > 0 { Divider().padding(.leading, 60) }
                        LeaderboardRow(rank: item.rank, entry: item.entry)
                    }
                }
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Settings")

            VStack(spacing: 0) {
                settingsRow(icon: "bell",                          label: "Notifications",    title: "Notifications")
                Divider().padding(.leading, 52)
                settingsRow(icon: "camera",                        label: "Scan preferences", title: "Scan preferences")
                Divider().padding(.leading, 52)
                settingsRow(icon: "lock",                          label: "Privacy",          title: "Privacy")
                Divider().padding(.leading, 52)
                settingsRow(icon: "square.and.arrow.up",           label: "Export collection",title: "Export collection")
                Divider().padding(.leading, 52)
                signOutRow
            }
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func settingsRow(icon: String, label: String, title: String) -> some View {
        NavigationLink(destination: PlaceholderSettingView(title: title)) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.primary)
                    .frame(width: 24)
                Text(label)
                    .bodyStyle(size: 15)
                    .foregroundStyle(theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var signOutRow: some View {
        Button {
            authService.signOut()
            router.isAuthenticated = false
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "E74C3C"))
                    .frame(width: 24)
                Text("Sign out")
                    .bodyStyle(size: 15)
                    .foregroundStyle(Color(hex: "E74C3C"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .bodyStyle(size: 13, weight: .semibold)
            .foregroundStyle(theme.inkMuted)
            .textCase(.uppercase)
    }
}

// MARK: - ProfileStatCell

private struct ProfileStatCell: View {
    let value: Int
    let label: String
    let color: Color
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .displayStyle(size: 22)
                .foregroundStyle(color)
            Text(label)
                .bodyStyle(size: 11)
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BadgeCard

private struct BadgeCard: View {
    let badge: Badge
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.unlocked ? theme.primary.opacity(0.15) : theme.chip)
                    .frame(width: 56, height: 56)
                Image(systemName: badge.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(badge.unlocked ? theme.primary : theme.inkMuted)
            }
            Text(badge.title)
                .bodyStyle(size: 11, weight: .medium)
                .foregroundStyle(badge.unlocked ? theme.ink : theme.inkMuted)
                .multilineTextAlignment(.center)
                .frame(width: 80)
            if let progress = badge.progress {
                Text(progress)
                    .monoStyle(size: 10)
                    .foregroundStyle(theme.primary)
            } else if badge.unlocked {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.success)
            } else {
                Spacer().frame(height: 14)
            }
        }
        .padding(12)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .opacity(badge.unlocked ? 1 : 0.55)
    }
}

// MARK: - LeaderboardRow

private struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .monoStyle(size: 13)
                .foregroundStyle(rank <= 3 ? theme.primary : theme.inkMuted)
                .frame(width: 30, alignment: .leading)

            let initial = entry.handle.first.map(String.init) ?? "?"
            Text(initial.uppercased())
                .bodyStyle(size: 13, weight: .semibold)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color(hex: "C8511B"), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .bodyStyle(size: 14, weight: entry.isMe ? .semibold : .regular)
                    .foregroundStyle(entry.isMe ? theme.primary : theme.ink)
                Text("@\(entry.handle)")
                    .bodyStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.ownedCount)")
                    .monoStyle(size: 13)
                    .foregroundStyle(entry.isMe ? theme.primary : theme.ink)
                Text("\(Int(Double(entry.ownedCount) / 670 * 100))%")
                    .bodyStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(entry.isMe ? theme.primary.opacity(0.06) : Color.clear)
    }
}

// MARK: - PlaceholderSettingView

private struct PlaceholderSettingView: View {
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 36))
                .foregroundStyle(theme.inkMuted)
            Text("\(title) settings coming soon")
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Sticker.self, UserCollection.self, Friendship.self, Trade.self,
        configurations: config
    )
    let f1 = Friendship(userID: "me", friendID: "f1", friendUsername: "Takashi Yamamoto",
                        friendHandle: "takashi_wc26", friendOwnedCount: 450, status: "accepted")
    let f2 = Friendship(userID: "me", friendID: "f2", friendUsername: "Maria García",
                        friendHandle: "maria_esp", friendOwnedCount: 310, status: "accepted")
    let t1 = Trade(id: "t1", proposerID: "me", recipientID: "f1", status: "completed",
                   offeredStickers: ["ARG-10"], requestedStickers: ["BRA-7"])
    let s1 = Sticker(id: "ARG-10", countryCode: "ARG", stickerNumber: 10,
                     type: "player", playerName: "L. Messi", position: "FWD", nationalTeam: "Argentina")
    let uc1 = UserCollection(userID: "me", stickerID: "ARG-10", quantityOwned: 3)
    [f1, f2, t1, s1, uc1].forEach { container.mainContext.insert($0) }
    s1.collection = uc1
    try? container.mainContext.save()

    return NavigationStack { ProfileView() }
        .modelContainer(container)
        .environment(AuthService(apiClient: APIClient()))
}
