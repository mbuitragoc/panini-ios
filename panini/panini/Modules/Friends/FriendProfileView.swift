import SwiftUI
import SwiftData

// MARK: - FriendProfileView

struct FriendProfileView: View {
    let friendship: Friendship

    @Environment(\.theme) private var theme
    @Environment(FriendService.self) private var friendService
    @Environment(AuthService.self) private var authService

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @State private var friendCollection: [FriendCollectionItem]
    @State private var isLoading = false
    @State private var loadError = false
    @State private var suggestionIndex = 0

    // Convenience init for previews with pre-loaded data
    init(friendship: Friendship, previewCollection: [FriendCollectionItem] = []) {
        self.friendship = friendship
        self._friendCollection = State(initialValue: previewCollection)
    }

    // MARK: - Trade opportunity computation

    private var friendCollectionMap: [String: FriendCollectionItem] {
        Dictionary(uniqueKeysWithValues: friendCollection.map { ($0.stickerID, $0) })
    }

    /// My wishlist ∩ friend's non-blacklisted dupes (they have extra, I want it)
    private var theyHaveINeed: [Sticker] {
        friendCollection.isEmpty ? [] : allStickers.filter { s in
            guard s.collection?.wishlisted == true else { return false }
            guard let fc = friendCollectionMap[s.id] else { return false }
            return fc.quantityOwned > 1 && !fc.blacklisted
        }
    }

    /// Friend's wishlist ∩ my non-blacklisted dupes (I have extra, they want it)
    private var youHaveTheyNeed: [Sticker] {
        friendCollection.isEmpty ? [] : allStickers.filter { s in
            guard (s.collection?.quantityOwned ?? 0) > 1,
                  !(s.collection?.blacklisted ?? false) else { return false }
            guard let fc = friendCollectionMap[s.id] else { return false }
            return fc.wishlisted
        }
    }

    private var hasTrades: Bool { !theyHaveINeed.isEmpty || !youHaveTheyNeed.isEmpty }

    private var suggestedPairs: [SuggestedTrade] {
        guard !friendCollection.isEmpty else { return [] }
        let myWishlist = allStickers.filter { $0.collection?.wishlisted == true }.map(\.id)
        let myDupes = allStickers.filter {
            ($0.collection?.quantityOwned ?? 0) > 1 && !($0.collection?.blacklisted ?? false)
        }.map(\.id)
        let theirWishlist = friendCollection.filter { $0.wishlisted }.map(\.stickerID)
        let theirDupes = friendCollection.filter { $0.quantityOwned > 1 && !$0.blacklisted }.map(\.stickerID)
        return StickerMatcher.match(
            myWishlist: myWishlist,
            myAvailableDupes: myDupes,
            theirWishlist: theirWishlist,
            theirAvailableDupes: theirDupes
        )
    }

    private func stickerByID(_ id: String) -> Sticker? {
        allStickers.first { $0.id == id }
    }

    private var totalStickers: Int { allStickers.count > 0 ? allStickers.count : 670 }
    private var completionPct: Double {
        Double(friendship.friendOwnedCount) / Double(totalStickers)
    }

    private var displayName: String {
        friendship.friendUsername.isEmpty ? friendship.friendHandle : friendship.friendUsername
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                if isLoading {
                    ProgressView("Loading collection…")
                        .padding(.vertical, 40)
                } else if loadError {
                    errorState
                } else if friendCollection.isEmpty {
                    noDataState
                } else {
                    tradeSummary
                    if hasTrades {
                        tradeStrips
                    } else {
                        emptyTradeState
                    }
                    if !suggestedPairs.isEmpty {
                        suggestedPairSection
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(theme.bg)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCollectionIfNeeded() }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Avatar
                let initial = friendship.friendHandle.first.map(String.init) ?? "?"
                Text(initial.uppercased())
                    .displayStyle(size: 32)
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Color(hex: "C8511B"), in: Circle())

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(theme.chip, lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: completionPct)
                        .stroke(theme.primary,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: completionPct)

                    VStack(spacing: 1) {
                        Text("\(Int(completionPct * 100))%")
                            .displayStyle(size: 18)
                            .foregroundStyle(theme.ink)
                        Text("done")
                            .bodyStyle(size: 10)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .frame(width: 80, height: 80)
            }

            VStack(spacing: 4) {
                Text(displayName)
                    .displayStyle(size: 22)
                    .foregroundStyle(theme.ink)
                Text("@\(friendship.friendHandle)")
                    .monoStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
                Text("\(friendship.friendOwnedCount) of \(totalStickers) stickers")
                    .bodyStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Trade summary chip

    private var tradeSummary: some View {
        let theyCount = theyHaveINeed.count
        let youCount = youHaveTheyNeed.count
        let name = friendship.friendUsername.isEmpty
            ? friendship.friendHandle
            : friendship.friendUsername.components(separatedBy: " ").first ?? friendship.friendHandle

        let text: String
        if theyCount == 0 && youCount == 0 {
            text = "No mutual trade opportunities right now"
        } else if theyCount > 0 && youCount > 0 {
            text = "\(name) has \(theyCount) sticker\(theyCount == 1 ? "" : "s") you need and wants \(youCount) of yours"
        } else if theyCount > 0 {
            text = "\(name) has \(theyCount) sticker\(theyCount == 1 ? "" : "s") you need"
        } else {
            text = "You have \(youCount) sticker\(youCount == 1 ? "" : "s") \(name) wants"
        }

        return Text(text)
            .bodyStyle(size: 14)
            .foregroundStyle(theme.inkSoft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Trade strips

    private var tradeStrips: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !theyHaveINeed.isEmpty {
                stripSection(
                    title: "They have / you need",
                    subtitle: "\(theyHaveINeed.count) sticker\(theyHaveINeed.count == 1 ? "" : "s")",
                    stickers: theyHaveINeed
                )
            }

            if !youHaveTheyNeed.isEmpty {
                stripSection(
                    title: "You have / they need",
                    subtitle: "\(youHaveTheyNeed.count) sticker\(youHaveTheyNeed.count == 1 ? "" : "s")",
                    stickers: youHaveTheyNeed
                )
            }

            proposeTradeButton
        }
    }

    private func stripSection(title: String, subtitle: String, stickers: [Sticker]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .bodyStyle(size: 14, weight: .semibold)
                        .foregroundStyle(theme.ink)
                    Text(subtitle)
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stickers, id: \.id) { sticker in
                        NavigationLink(value: sticker) {
                            StickerCard(sticker: sticker, collection: sticker.collection, width: 88)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private var proposeTradeButton: some View {
        NavigationLink {
            ProposeTradeView(
                friendID: friendship.friendID,
                offeredStickerIDs: youHaveTheyNeed.map(\.id),
                requestedStickerIDs: theyHaveINeed.map(\.id)
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                Text("Propose trade")
            }
            .bodyStyle(size: 16, weight: .semibold)
            .foregroundStyle(theme.primaryInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 4)
    }

    // MARK: - Suggested pair carousel

    private var suggestedPairSection: some View {
        let clampedIndex = min(suggestionIndex, suggestedPairs.count - 1)
        let pair = suggestedPairs[clampedIndex]
        let giveSticker = stickerByID(pair.give)
        let receiveSticker = stickerByID(pair.receive)
        let name = friendship.friendUsername.isEmpty
            ? friendship.friendHandle
            : friendship.friendUsername.components(separatedBy: " ").first ?? friendship.friendHandle

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUGGESTED · FAIR TRADE")
                        .monoStyle(size: 10)
                        .foregroundStyle(theme.primary)
                    Text("\(clampedIndex + 1) of \(suggestedPairs.count)")
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("You give")
                        .bodyStyle(size: 11)
                        .foregroundStyle(theme.inkMuted)
                    if let s = giveSticker {
                        StickerCard(sticker: s, collection: s.collection, width: 88)
                    } else {
                        stickerIDPlaceholder(pair.give)
                    }
                }

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Text("You get")
                        .bodyStyle(size: 11)
                        .foregroundStyle(theme.inkMuted)
                    if let s = receiveSticker {
                        StickerCard(sticker: s, collection: s.collection, width: 88)
                    } else {
                        stickerIDPlaceholder(pair.receive)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                if suggestionIndex < suggestedPairs.count - 1 {
                    Button {
                        withAnimation(.easeInOut) { suggestionIndex += 1 }
                    } label: {
                        Text("Skip")
                            .bodyStyle(size: 14, weight: .medium)
                            .foregroundStyle(theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.chip, in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                NavigationLink {
                    ProposeTradeView(
                        friendID: friendship.friendID,
                        offeredStickerIDs: [pair.give],
                        requestedStickerIDs: [pair.receive]
                    )
                } label: {
                    Text("Accept with \(name)")
                        .bodyStyle(size: 14, weight: .semibold)
                        .foregroundStyle(theme.primaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.primary.opacity(0.25), lineWidth: 1)
        )
    }

    private func stickerIDPlaceholder(_ id: String) -> some View {
        Text(id)
            .monoStyle(size: 11)
            .foregroundStyle(theme.inkMuted)
            .frame(width: 88, height: 110)
            .background(theme.chip, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - State views

    private var emptyTradeState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 40))
                .foregroundStyle(theme.inkMuted)
            Text("No trade matches yet")
                .bodyStyle(size: 15, weight: .medium)
                .foregroundStyle(theme.inkMuted)
            Text("Add stickers to your wishlist or build up duplicates to unlock trade opportunities.")
                .bodyStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var noDataState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundStyle(theme.inkMuted)
            Text("Collection unavailable")
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.vertical, 32)
    }

    private var errorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(theme.inkMuted)
            Text("Couldn't load collection")
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
            Button("Try again") { Task { await loadCollectionIfNeeded(force: true) } }
                .bodyStyle(size: 13)
                .foregroundStyle(theme.primary)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Data loading

    private func loadCollectionIfNeeded(force: Bool = false) async {
        guard friendCollection.isEmpty || force else { return }
        isLoading = true
        loadError = false
        do {
            let collection = try await friendService.fetchFriendCollection(friendID: friendship.friendID)
            friendCollection = collection
            suggestionIndex = 0
            // Cache match count on the Friendship record so the home screen teaser
            // and friends list can show real counts without re-fetching.
            let myWishlist = allStickers.filter { $0.collection?.wishlisted == true }.map(\.id)
            let myDupes = allStickers.filter {
                ($0.collection?.quantityOwned ?? 0) > 1 && !($0.collection?.blacklisted ?? false)
            }.map(\.id)
            let theirWishlist = collection.filter { $0.wishlisted }.map(\.stickerID)
            let theirDupes = collection.filter { $0.quantityOwned > 1 && !$0.blacklisted }.map(\.stickerID)
            friendship.tradeMatchCount = StickerMatcher.match(
                myWishlist: myWishlist,
                myAvailableDupes: myDupes,
                theirWishlist: theirWishlist,
                theirAvailableDupes: theirDupes
            ).count
        } catch {
            loadError = friendCollection.isEmpty
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview("Friend profile — with trade matches") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Friendship.self, Sticker.self, UserCollection.self,
        configurations: config
    )

    let friendship = Friendship(
        userID: "me",
        friendID: "friend-abc",
        friendUsername: "Takashi Yamamoto",
        friendHandle: "takashi_wc26",
        friendOwnedCount: 312,
        status: "accepted",
        sentByMe: true
    )
    container.mainContext.insert(friendship)

    // My stickers — two wishlisted (I need them), two dupes (I can offer)
    let s1 = Sticker(id: "BRA-7",  countryCode: "BRA", stickerNumber: 7,  type: "player",
                     playerName: "Vinicius Jr", position: "FWD", nationalTeam: "Brazil")
    let s2 = Sticker(id: "FRA-10", countryCode: "FRA", stickerNumber: 10, type: "player",
                     playerName: "K. Mbappé",   position: "FWD", nationalTeam: "France")
    let s3 = Sticker(id: "ARG-10", countryCode: "ARG", stickerNumber: 10, type: "player",
                     playerName: "L. Messi",    position: "FWD", nationalTeam: "Argentina")
    let s4 = Sticker(id: "ENG-9",  countryCode: "ENG", stickerNumber: 9,  type: "player",
                     playerName: "H. Kane",     position: "FWD", nationalTeam: "England")
    [s1, s2, s3, s4].forEach { container.mainContext.insert($0) }

    // My collection: BRA-7 and FRA-10 are wishlisted (I want them)
    let uc1 = UserCollection(userID: "me", stickerID: "BRA-7",  quantityOwned: 0, wishlisted: true)
    let uc2 = UserCollection(userID: "me", stickerID: "FRA-10", quantityOwned: 0, wishlisted: true)
    // ARG-10 and ENG-9 I have as dupes (I can offer)
    let uc3 = UserCollection(userID: "me", stickerID: "ARG-10", quantityOwned: 3)
    let uc4 = UserCollection(userID: "me", stickerID: "ENG-9",  quantityOwned: 2)
    [uc1, uc2, uc3, uc4].forEach { container.mainContext.insert($0) }
    s1.collection = uc1; s2.collection = uc2; s3.collection = uc3; s4.collection = uc4
    try? container.mainContext.save()

    // Friend's collection: has BRA-7 and FRA-10 as dupes; wishlists ARG-10 and ENG-9
    let previewCollection = [
        FriendCollectionItem(stickerID: "BRA-7",  quantityOwned: 2, wishlisted: false, blacklisted: false),
        FriendCollectionItem(stickerID: "FRA-10", quantityOwned: 3, wishlisted: false, blacklisted: false),
        FriendCollectionItem(stickerID: "ARG-10", quantityOwned: 0, wishlisted: true,  blacklisted: false),
        FriendCollectionItem(stickerID: "ENG-9",  quantityOwned: 0, wishlisted: true,  blacklisted: false),
    ]

    return NavigationStack {
        FriendProfileView(friendship: friendship, previewCollection: previewCollection)
    }
    .modelContainer(container)
    .environment(FriendService(apiClient: APIClient()))
    .environment(AuthService(apiClient: APIClient()))
}

#Preview("Friend profile — no trades") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Friendship.self, Sticker.self, UserCollection.self,
        configurations: config
    )
    let friendship = Friendship(
        userID: "me", friendID: "friend-xyz",
        friendUsername: "Maria García", friendHandle: "maria_esp",
        friendOwnedCount: 128, status: "accepted", sentByMe: false
    )
    container.mainContext.insert(friendship)

    return NavigationStack {
        FriendProfileView(friendship: friendship, previewCollection: [
            FriendCollectionItem(stickerID: "COL-1", quantityOwned: 1, wishlisted: false, blacklisted: false)
        ])
    }
    .modelContainer(container)
    .environment(FriendService(apiClient: APIClient()))
    .environment(AuthService(apiClient: APIClient()))
}
