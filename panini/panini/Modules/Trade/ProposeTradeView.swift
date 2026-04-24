import SwiftUI
import SwiftData

// MARK: - ProposeTradeView

struct ProposeTradeView: View {
    let friendID: String
    let offeredStickerIDs: [String]
    let requestedStickerIDs: [String]

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @State private var isSending = false
    @State private var showConfirmation = false

    private var offeredStickers: [Sticker] {
        let ids = Set(offeredStickerIDs)
        return allStickers.filter { ids.contains($0.id) }
    }

    private var requestedStickers: [Sticker] {
        let ids = Set(requestedStickerIDs)
        return allStickers.filter { ids.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                tradeSection(
                    title: "You're offering",
                    subtitle: "\(offeredStickers.count) sticker\(offeredStickers.count == 1 ? "" : "s")",
                    stickers: offeredStickers,
                    accentColor: theme.primary
                )

                divider

                tradeSection(
                    title: "You're requesting",
                    subtitle: "\(requestedStickers.count) sticker\(requestedStickers.count == 1 ? "" : "s")",
                    stickers: requestedStickers,
                    accentColor: Color(hex: "2196F3")
                )

                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(theme.bg)
        .navigationTitle("Propose Trade")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Trade proposal sent!", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your friend will be notified and can accept or decline.")
        }
    }

    // MARK: - Subviews

    private func tradeSection(title: String, subtitle: String, stickers: [Sticker], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .bodyStyle(size: 15, weight: .semibold)
                        .foregroundStyle(theme.ink)
                    Text(subtitle)
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().fill(accentColor))
            }

            if stickers.isEmpty {
                emptySection
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stickers, id: \.id) { sticker in
                            StickerCard(sticker: sticker, collection: sticker.collection, width: 88)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptySection: some View {
        Text("No stickers selected")
            .bodyStyle(size: 13)
            .foregroundStyle(theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(theme.chip)
                .frame(height: 1)
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.inkMuted)
            Rectangle()
                .fill(theme.chip)
                .frame(height: 1)
        }
    }

    private var sendButton: some View {
        Button {
            Task { await sendProposal() }
        } label: {
            Group {
                if isSending {
                    ProgressView()
                        .tint(theme.primaryInk)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Send proposal")
                    }
                    .bodyStyle(size: 16, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isSending || (offeredStickers.isEmpty && requestedStickers.isEmpty))
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func sendProposal() async {
        isSending = true
        // Trade API implemented in issue #14
        try? await Task.sleep(nanoseconds: 500_000_000)
        isSending = false
        showConfirmation = true
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Sticker.self, UserCollection.self,
        configurations: config
    )

    let s1 = Sticker(id: "ARG-10", countryCode: "ARG", stickerNumber: 10, type: "player",
                     playerName: "L. Messi", position: "FWD", nationalTeam: "Argentina")
    let s2 = Sticker(id: "ENG-9", countryCode: "ENG", stickerNumber: 9, type: "player",
                     playerName: "H. Kane", position: "FWD", nationalTeam: "England")
    let s3 = Sticker(id: "BRA-7", countryCode: "BRA", stickerNumber: 7, type: "player",
                     playerName: "Vinicius Jr", position: "FWD", nationalTeam: "Brazil")
    let uc1 = UserCollection(userID: "me", stickerID: "ARG-10", quantityOwned: 3)
    let uc2 = UserCollection(userID: "me", stickerID: "ENG-9", quantityOwned: 2)
    [s1, s2, s3].forEach { container.mainContext.insert($0) }
    [uc1, uc2].forEach { container.mainContext.insert($0) }
    s1.collection = uc1; s2.collection = uc2
    try? container.mainContext.save()

    return NavigationStack {
        ProposeTradeView(
            friendID: "friend-abc",
            offeredStickerIDs: ["ARG-10", "ENG-9"],
            requestedStickerIDs: ["BRA-7"]
        )
    }
    .modelContainer(container)
}
