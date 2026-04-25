import SwiftUI
import SwiftData

// MARK: - TradeDetailView

struct TradeDetailView: View {
    let trade: Trade
    let myID: String

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(TradeService.self) private var tradeService
    @Environment(SyncEngine.self) private var syncEngine

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]
    @Query private var friendships: [Friendship]

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

    private func stickers(for ids: [String]) -> [Sticker] {
        let set = Set(ids)
        return allStickers.filter { set.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusHeader
                stickerSection(
                    title: isProposer ? "You're offering" : "\(friendName) offers",
                    ids: trade.offeredStickers,
                    color: theme.primary
                )
                stickerSection(
                    title: isProposer ? "You're requesting" : "\(friendName) requests",
                    ids: trade.requestedStickers,
                    color: Color(hex: "2196F3")
                )
                timelineSection
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(theme.bg)
        .navigationTitle("Trade details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await syncEngine.sync(context: context)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                await syncEngine.sync(context: context)
            }
        }
    }

    // MARK: - Status header

    private var statusHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isProposer ? "YOU PROPOSED TO" : "PROPOSED BY")
                    .monoStyle(size: 10)
                    .foregroundStyle(theme.inkMuted)
                    .tracking(1)
                Text(friendName)
                    .displayStyle(size: 22)
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            Text(statusLabel)
                .bodyStyle(size: 13, weight: .semibold)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sticker section

    private func stickerSection(title: String, ids: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .bodyStyle(size: 15, weight: .semibold)
                    .foregroundStyle(theme.ink)
                Text("(\(ids.count))")
                    .bodyStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }

            let matched = stickers(for: ids)
            let missing = ids.filter { id in !matched.contains(where: { $0.id == id }) }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(matched, id: \.id) { s in
                    StickerCard(sticker: s, collection: s.collection, width: 100)
                }
                ForEach(missing, id: \.self) { id in
                    Text(id)
                        .monoStyle(size: 11)
                        .foregroundStyle(theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(width: 100, height: 130)
                        .background(theme.chip, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TIMELINE")
                .monoStyle(size: 10)
                .foregroundStyle(theme.inkMuted)
                .tracking(1.2)
                .padding(.bottom, 14)

            timelineRow(label: "Proposed", date: trade.proposedAt,
                        active: true, dotColor: theme.ink,
                        isLast: trade.resolvedAt == nil && trade.completedAt == nil)

            if let resolvedAt = trade.resolvedAt {
                let isDeclined = status == .declined
                timelineRow(
                    label: isDeclined ? "Declined" : "Accepted",
                    date: resolvedAt,
                    active: true,
                    dotColor: isDeclined ? Color(hex: "E74C3C") : theme.primary,
                    isLast: trade.completedAt == nil && !isDeclined
                )
            } else if status != .proposed && status != .none {
                timelineRow(label: "Accepted", date: nil, active: false, isLast: trade.completedAt == nil)
            }

            if status == .accepted || status == .proposerConfirmed {
                timelineRow(label: "Confirming exchange", date: nil, active: false, isLast: true)
            } else if let completedAt = trade.completedAt {
                timelineRow(label: "Completed", date: completedAt,
                            active: true, dotColor: theme.success, isLast: true)
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func timelineRow(
        label: String,
        date: Date?,
        active: Bool,
        dotColor: Color? = nil,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(active ? (dotColor ?? theme.ink) : theme.chip)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(theme.chip)
                        .frame(width: 2)
                        .frame(minHeight: 28)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .bodyStyle(size: 14, weight: active ? .medium : .regular)
                    .foregroundStyle(active ? theme.ink : theme.inkMuted)
                Text(date.map { $0.formatted(date: .long, time: .omitted) } ?? "Pending")
                    .bodyStyle(size: 12)
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.bottom, isLast ? 0 : 16)
            Spacer()
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch status {
        case .proposed where !isProposer:
            HStack(spacing: 12) {
                Button { handle(.decline) } label: {
                    Text("Decline")
                        .bodyStyle(size: 16, weight: .medium)
                        .foregroundStyle(theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.chip, in: RoundedRectangle(cornerRadius: 14))
                }
                Button { handle(.accept) } label: {
                    Text("Accept")
                        .bodyStyle(size: 16, weight: .semibold)
                        .foregroundStyle(theme.primaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .buttonStyle(.plain)

        case .accepted where isProposer,
             .proposerConfirmed where !isProposer:
            Button { handle(.confirm) } label: {
                Text("Confirm exchange")
                    .bodyStyle(size: 16, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

        default:
            EmptyView()
        }
    }

    private func handle(_ action: TradeAction) {
        Task {
            do {
                switch action {
                case .accept:  try await tradeService.accept(tradeID: trade.id)
                case .decline: try await tradeService.decline(tradeID: trade.id)
                case .confirm: try await tradeService.confirm(tradeID: trade.id)
                }
                syncEngine.syncAfterWrite(context: context)
            } catch {}
        }
    }
}
