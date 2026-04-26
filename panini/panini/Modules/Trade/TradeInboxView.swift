import SwiftUI
import SwiftData

// MARK: - InboxTab

private enum InboxTab: String, CaseIterable {
    case received = "Received"
    case active   = "Active"
    case history  = "History"
}

// MARK: - TradeInboxView

struct TradeInboxView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var authService
    @Environment(TradeService.self) private var tradeService
    @Environment(SyncEngine.self) private var syncEngine

    @Query(sort: \Trade.proposedAt, order: .reverse) private var trades: [Trade]
    @Query private var friendships: [Friendship]

    @State private var selectedTab: InboxTab = .received
    @State private var selectedTrade: Trade?
    @State private var acceptTrigger  = false
    @State private var declineTrigger = false
    @State private var confirmTrigger = false

    private var myID: String { authService.currentUserID ?? "" }

    // MARK: - Filtered lists

    private var received: [Trade] {
        trades.filter { $0.recipientID == myID && $0.status == "proposed" }
    }

    /// All in-progress trades where the user is either side, excluding those already in "received".
    private var active: [Trade] {
        trades.filter { t in
            let involved = t.proposerID == myID || t.recipientID == myID
            let inProgress = ["proposed", "accepted", "proposer_confirmed"].contains(t.status)
            let notInReceived = !(t.recipientID == myID && t.status == "proposed")
            return involved && inProgress && notInReceived
        }
    }

    private var history: [Trade] {
        trades.filter { ["completed", "declined"].contains($0.status) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider().background(theme.chip)

            ScrollView {
                LazyVStack(spacing: 12) {
                    switch selectedTab {
                    case .received:
                        if received.isEmpty { emptyState(for: .received) }
                        else { ForEach(received, id: \.id) { t in TradeRow(trade: t, myID: myID, friendships: friendships, onAction: handle, onTap: { selectedTrade = t }) } }

                    case .active:
                        if active.isEmpty { emptyState(for: .active) }
                        else { ForEach(active, id: \.id) { t in TradeRow(trade: t, myID: myID, friendships: friendships, onAction: handle, onTap: { selectedTrade = t }) } }

                    case .history:
                        if history.isEmpty { emptyState(for: .history) }
                        else { ForEach(history, id: \.id) { t in TradeRow(trade: t, myID: myID, friendships: friendships, onAction: nil, onTap: { selectedTrade = t }) } }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(theme.bg)
        .navigationTitle("Trades")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedTrade) { trade in
            TradeDetailView(trade: trade, myID: myID)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: acceptTrigger)
        .sensoryFeedback(.impact(weight: .light),  trigger: declineTrigger)
        .sensoryFeedback(.impact(weight: .heavy),  trigger: confirmTrigger)
        .refreshable { await syncEngine.sync(context: context) }
        .task {
            // Sync immediately on appear, then every 15 s while the view is on screen.
            await syncEngine.sync(context: context)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                await syncEngine.sync(context: context)
            }
        }
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(InboxTab.allCases, id: \.self) { tab in
                let badge: Int = tab == .received ? received.count : 0
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .bodyStyle(size: 14, weight: selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(selectedTab == tab ? theme.ink : theme.inkMuted)
                        if badge > 0 {
                            Text("\(badge)")
                                .bodyStyle(size: 11, weight: .semibold)
                                .foregroundStyle(theme.primaryInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.primary, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(theme.primary)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private func emptyState(for tab: InboxTab) -> some View {
        let (icon, text): (String, String) = switch tab {
        case .received: ("tray", "No incoming trade requests")
        case .active:   ("paperplane", "No active trades")
        case .history:  ("clock", "No completed or declined trades yet")
        }
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(theme.inkMuted)
            Text(text)
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Action handler

    private func handle(_ trade: Trade, _ action: TradeAction) {
        // Fire haptic immediately on the main thread before the network call
        switch action {
        case .accept:  acceptTrigger.toggle()
        case .decline: declineTrigger.toggle()
        case .confirm: confirmTrigger.toggle()
        }
        Task {
            do {
                switch action {
                case .accept:  try await tradeService.accept(tradeID: trade.id)
                case .decline: try await tradeService.decline(tradeID: trade.id)
                case .confirm: try await tradeService.confirm(tradeID: trade.id)
                }
                syncEngine.syncAfterWrite(context: context)
            } catch {
                // Errors surfaced via sync status; no additional UI needed
            }
        }
    }
}

// MARK: - TradeAction

enum TradeAction {
    case accept, decline, confirm
}

// MARK: - TradeRow

private struct TradeRow: View {
    let trade: Trade
    let myID: String
    let friendships: [Friendship]
    let onAction: ((Trade, TradeAction) -> Void)?
    let onTap: (() -> Void)?

    @Environment(\.theme) private var theme

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    private var isProposer: Bool { trade.proposerID == myID }
    private var counterpartyID: String { isProposer ? trade.recipientID : trade.proposerID }
    private var status: TradeStatus? { TradeStatus(rawValue: trade.status) }

    private var friendName: String {
        if let f = friendships.first(where: { $0.friendID == counterpartyID }) {
            return f.friendUsername.isEmpty ? f.friendHandle : f.friendUsername
        }
        return "Friend"
    }

    private var statusLabel: String {
        switch status {
        case .proposed:           return isProposer ? "Awaiting response" : "Incoming offer"
        case .accepted:           return isProposer ? "Confirm exchange" : "Accepted"
        case .proposerConfirmed:  return isProposer ? "Waiting for them" : "Confirm exchange"
        case .declined:           return "Declined"
        case .completed:          return "Completed"
        case .none:               return trade.status
        }
    }

    private var statusColor: Color {
        switch status {
        case .proposed:                       return theme.inkMuted
        case .accepted, .proposerConfirmed:   return theme.primary
        case .declined:                       return Color(hex: "E74C3C")
        case .completed:                      return theme.success
        case .none:                           return theme.inkMuted
        }
    }

    private func stickerThumbnails(for ids: [String], max: Int) -> (matched: [Sticker], extra: Int) {
        let set = Set(ids)
        let matched = allStickers.filter { set.contains($0.id) }
        let shown = Array(matched.prefix(max))
        return (shown, ids.count - shown.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(friendName)
                        .bodyStyle(size: 15, weight: .semibold)
                        .foregroundStyle(theme.ink)
                    Text(isProposer ? "You proposed" : "They proposed")
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Text(statusLabel)
                    .bodyStyle(size: 12, weight: .medium)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }

            // Compact sticker preview
            stickerPreviewRow

            // Date + detail hint
            HStack {
                Text(trade.proposedAt.formatted(date: .abbreviated, time: .omitted))
                    .monoStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                HStack(spacing: 3) {
                    Text("Details")
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.inkMuted)
                }
            }

            if let onAction {
                actionButtons(onAction)
            }
        }
        .padding(14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { onTap?() }
    }

    // Inline mini preview: up to 2 thumbnails per side + overflow count
    private var stickerPreviewRow: some View {
        let (offeredShown, offeredExtra) = stickerThumbnails(for: trade.offeredStickers, max: 2)
        let (requestedShown, requestedExtra) = stickerThumbnails(for: trade.requestedStickers, max: 2)

        return HStack(spacing: 6) {
            ForEach(offeredShown, id: \.id) { s in
                StickerCard(sticker: s, collection: s.collection, width: 52)
            }
            if offeredExtra > 0 {
                Text("+\(offeredExtra)")
                    .monoStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
                    .frame(width: 52, height: 68)
                    .background(theme.chip, in: RoundedRectangle(cornerRadius: 8))
            }

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 4)

            ForEach(requestedShown, id: \.id) { s in
                StickerCard(sticker: s, collection: s.collection, width: 52)
            }
            if requestedExtra > 0 {
                Text("+\(requestedExtra)")
                    .monoStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
                    .frame(width: 52, height: 68)
                    .background(theme.chip, in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func actionButtons(_ onAction: @escaping (Trade, TradeAction) -> Void) -> some View {
        switch status {
        case .proposed where !isProposer:
            HStack(spacing: 10) {
                Button { onAction(trade, .decline) } label: {
                    Text("Decline")
                        .bodyStyle(size: 14, weight: .medium)
                        .foregroundStyle(theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.chip, in: RoundedRectangle(cornerRadius: 10))
                }
                Button { onAction(trade, .accept) } label: {
                    Text("Accept")
                        .bodyStyle(size: 14, weight: .semibold)
                        .foregroundStyle(theme.primaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)

        case .accepted where isProposer,
             .proposerConfirmed where !isProposer:
            Button { onAction(trade, .confirm) } label: {
                Text("Confirm exchange")
                    .bodyStyle(size: 14, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.primary, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Trade.self, Friendship.self,
        configurations: config
    )
    let myID = "user-me"

    let t1 = Trade(id: "t1", proposerID: "user-friend", recipientID: myID,
                   status: "proposed", offeredStickers: ["BRA-7", "FRA-10"],
                   requestedStickers: ["ARG-10"])
    let t2 = Trade(id: "t2", proposerID: myID, recipientID: "user-friend",
                   status: "accepted", offeredStickers: ["ENG-9"],
                   requestedStickers: ["ESP-5", "GER-3"])
    let t3 = Trade(id: "t3", proposerID: "user-friend", recipientID: myID,
                   status: "completed", offeredStickers: ["POR-7"],
                   requestedStickers: ["ARG-10"])
    [t1, t2, t3].forEach { container.mainContext.insert($0) }

    let friendship = Friendship(userID: myID, friendID: "user-friend",
                                friendUsername: "Takashi Yamamoto",
                                friendHandle: "takashi_wc26",
                                friendOwnedCount: 312, status: "accepted")
    container.mainContext.insert(friendship)
    try! container.mainContext.save()

    let authService = AuthService(apiClient: APIClient())
    return NavigationStack {
        TradeInboxView()
    }
    .modelContainer(container)
    .environment(authService)
    .environment(TradeService(apiClient: APIClient()))
    .environment(SyncEngine(apiClient: APIClient()))
}
