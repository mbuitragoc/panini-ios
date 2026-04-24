import SwiftUI
import SwiftData

// MARK: - InboxTab

private enum InboxTab: String, CaseIterable {
    case received = "Received"
    case sent     = "Sent"
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

    private var myID: String { authService.currentUserID ?? "" }

    // MARK: - Filtered lists

    private var received: [Trade] {
        trades.filter { $0.recipientID == myID && $0.status == "proposed" }
    }

    private var sent: [Trade] {
        trades.filter {
            $0.proposerID == myID
            && ["proposed", "accepted", "proposer_confirmed"].contains($0.status)
        }
    }

    private var history: [Trade] {
        trades.filter { ["completed", "declined"].contains($0.status) }
    }

    private var activeTrades: [Trade] {
        trades.filter {
            ($0.proposerID == myID || $0.recipientID == myID)
            && ["accepted", "proposer_confirmed"].contains($0.status)
        }
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
                        else { ForEach(received, id: \.id) { TradeRow(trade: $0, myID: myID, friendships: friendships, onAction: handle) } }

                    case .sent:
                        if activeTrades.filter({ $0.proposerID == myID }).isEmpty && sent.filter({ $0.status == "proposed" }).isEmpty {
                            emptyState(for: .sent)
                        } else {
                            let pendingConfirm = activeTrades.filter { $0.proposerID == myID && $0.status == "accepted" }
                            let inProgress = sent.filter { $0.status == "proposed" }
                            ForEach(pendingConfirm + inProgress, id: \.id) { TradeRow(trade: $0, myID: myID, friendships: friendships, onAction: handle) }
                        }

                    case .history:
                        if history.isEmpty { emptyState(for: .history) }
                        else { ForEach(history, id: \.id) { TradeRow(trade: $0, myID: myID, friendships: friendships, onAction: nil) } }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(theme.bg)
        .navigationTitle("Trades")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await syncEngine.sync(context: context) }
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

    private func emptyState(for tab: InboxTab) -> some View {
        let (icon, text): (String, String) = switch tab {
        case .received: ("tray", "No incoming trade requests")
        case .sent:     ("paperplane", "No active trade proposals")
        case .history:  ("clock", "No completed or declined trades yet")
        }
        return VStack(spacing: 12) {
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

    @Environment(\.theme) private var theme

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
        case .proposed:           return theme.inkMuted
        case .accepted:           return theme.primary
        case .proposerConfirmed:  return theme.primary
        case .declined:           return Color(hex: "E74C3C")
        case .completed:          return theme.success
        case .none:               return theme.inkMuted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            HStack(spacing: 8) {
                stickerCountChip(
                    label: "\(trade.offeredStickers.count) offered",
                    color: theme.primary
                )
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkMuted)
                stickerCountChip(
                    label: "\(trade.requestedStickers.count) requested",
                    color: Color(hex: "2196F3")
                )
            }

            if let onAction {
                actionButtons(onAction)
            }
        }
        .padding(14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stickerCountChip(label: String, color: Color) -> some View {
        Text(label)
            .bodyStyle(size: 12)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: Capsule())
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

        case .accepted where isProposer:
            Button { onAction(trade, .confirm) } label: {
                Text("Confirm exchange")
                    .bodyStyle(size: 14, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.primary, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

        case .proposerConfirmed where !isProposer:
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
    try? container.mainContext.save()

    let authService = AuthService(apiClient: APIClient())
    return NavigationStack {
        TradeInboxView()
    }
    .modelContainer(container)
    .environment(authService)
    .environment(TradeService(apiClient: APIClient()))
    .environment(SyncEngine(apiClient: APIClient()))
}
