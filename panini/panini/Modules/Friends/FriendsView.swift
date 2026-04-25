import SwiftUI
import SwiftData

// MARK: - FriendsView

struct FriendsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var authService
    @Environment(FriendService.self) private var friendService
    @Environment(SyncEngine.self) private var syncEngine

    @Query(sort: \Friendship.updatedAt, order: .reverse) private var friendships: [Friendship]
    @Query(sort: \Trade.proposedAt, order: .reverse) private var trades: [Trade]

    @State private var showAddFriend = false
    @State private var showTradeInbox = false

    private var myID: String { authService.currentUserID ?? "" }
    private var pendingTradeCount: Int {
        trades.filter { $0.recipientID == myID && $0.status == "proposed" }.count
    }

    private var incoming: [Friendship] {
        friendships.filter { $0.status == "pending" && !$0.sentByMe }
    }

    private var accepted: [Friendship] {
        friendships.filter { $0.status == "accepted" }
    }

    var body: some View {
        List {
            if !incoming.isEmpty {
                Section("Requests") {
                    ForEach(incoming) { f in
                        PendingRequestRow(friendship: f) { accept in
                            respondToRequest(f, accept: accept)
                        }
                    }
                }
            }

            Section("Friends") {
                if accepted.isEmpty {
                    emptyState
                } else {
                    ForEach(accepted) { f in
                        NavigationLink(value: f) {
                            FriendRow(friendship: f)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Friendship.self) { FriendProfileView(friendship: $0) }
        .navigationDestination(isPresented: $showTradeInbox) { TradeInboxView() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showTradeInbox = true } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(theme.primary)
                }
                .overlay(alignment: .topTrailing) {
                    if pendingTradeCount > 0 {
                        Text("\(pendingTradeCount)")
                            .bodyStyle(size: 10, weight: .semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                            .offset(x: 10, y: -8)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddFriend = true } label: {
                    Image(systemName: "person.badge.plus")
                }
                .foregroundStyle(theme.primary)
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .refreshable {
            await syncEngine.sync(context: context)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 36))
                .foregroundStyle(theme.inkMuted)
            Text("No friends yet")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkMuted)
            Text("Tap + to add friends by QR or username")
                .bodyStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }

    private func respondToRequest(_ f: Friendship, accept: Bool) {
        Task {
            try? await friendService.respondToRequest(senderID: f.friendID, accept: accept)
            syncEngine.syncAfterWrite(context: context)
        }
    }
}

// MARK: - PendingRequestRow

private struct PendingRequestRow: View {
    let friendship: Friendship
    let onRespond: (Bool) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            avatarCircle(friendship.friendHandle)

            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.friendUsername.isEmpty ? friendship.friendHandle : friendship.friendUsername)
                    .bodyStyle(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
                Text("@\(friendship.friendHandle)")
                    .bodyStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            HStack(spacing: 8) {
                Button { onRespond(true) } label: {
                    Text("Accept")
                        .bodyStyle(size: 13, weight: .semibold)
                        .foregroundStyle(theme.primaryInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.primary, in: Capsule())
                }

                Button { onRespond(false) } label: {
                    Text("Decline")
                        .bodyStyle(size: 13)
                        .foregroundStyle(theme.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.chip, in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .listRowBackground(theme.surface)
    }
}

// MARK: - FriendRow

private struct FriendRow: View {
    let friendship: Friendship

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            avatarCircle(friendship.friendHandle)

            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.friendUsername.isEmpty ? friendship.friendHandle : friendship.friendUsername)
                    .bodyStyle(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
                Text("@\(friendship.friendHandle)")
                    .bodyStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(friendship.friendOwnedCount)/670")
                    .monoStyle(size: 12)
                    .foregroundStyle(theme.ink)
                Text("stickers")
                    .bodyStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
                if friendship.tradeMatchCount > 0 {
                    Text("\(friendship.tradeMatchCount) trade\(friendship.tradeMatchCount == 1 ? "" : "s")")
                        .bodyStyle(size: 11, weight: .semibold)
                        .foregroundStyle(theme.primaryInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.primary, in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(theme.surface)
    }
}

// MARK: - Avatar helper

private func avatarCircle(_ handle: String) -> some View {
    let initial = handle.first.map(String.init) ?? "?"
    return Text(initial.uppercased())
        .bodyStyle(size: 16, weight: .semibold)
        .foregroundStyle(.white)
        .frame(width: 40, height: 40)
        .background(Color(hex: "C8511B"), in: Circle())
}
