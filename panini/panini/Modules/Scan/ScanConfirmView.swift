import SwiftUI
import SwiftData

// MARK: - ScanConfirmView

struct ScanConfirmView: View {
    let stickerID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(SyncEngine.self) private var syncEngine

    @Query private var allStickers: [Sticker]

    private var sticker: Sticker? { allStickers.first { $0.id == stickerID } }
    private var alreadyOwned: Bool { (sticker?.collection?.quantityOwned ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if let sticker {
                        heroCard(sticker)
                        infoSection(sticker)
                        if alreadyOwned { duplicateNotice }
                        addButton(sticker)
                    } else {
                        notFound
                    }
                }
                .padding(24)
            }
            .background(theme.bg)
            .navigationTitle("Add sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Scan again") { dismiss() }
                        .bodyStyle(size: 15)
                }
            }
        }
    }

    // MARK: - Hero card

    @ViewBuilder
    private func heroCard(_ sticker: Sticker) -> some View {
        // Show the card in full colour even if not yet owned.
        let preview = UserCollection(
            userID: "",
            stickerID: sticker.id,
            quantityOwned: 1
        )
        StickerCard(sticker: sticker, collection: preview, width: 180)
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    // MARK: - Info section

    @ViewBuilder
    private func infoSection(_ sticker: Sticker) -> some View {
        VStack(spacing: 6) {
            if let name = sticker.playerName {
                Text(name)
                    .displayStyle(size: 26)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Text(sticker.nationalTeam)
                    .bodyStyle(size: 14, weight: .medium)
                    .foregroundStyle(theme.inkSoft)

                if let pos = sticker.position {
                    Text("·")
                        .foregroundStyle(theme.inkMuted)
                    Text(pos)
                        .bodyStyle(size: 14)
                        .foregroundStyle(theme.inkMuted)
                }
            }

            Text(sticker.id)
                .monoStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 2)
        }
    }

    // MARK: - Duplicate notice

    private var duplicateNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.on.square")
                .font(.system(size: 14))
            Text("Already in your collection — this will be a duplicate")
                .bodyStyle(size: 13)
        }
        .foregroundStyle(theme.inkSoft)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.chip, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Add button

    @ViewBuilder
    private func addButton(_ sticker: Sticker) -> some View {
        Button {
            save(sticker)
        } label: {
            Text(alreadyOwned ? "Add duplicate" : "Add to collection")
                .bodyStyle(size: 17, weight: .semibold)
                .foregroundStyle(theme.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Not found fallback

    private var notFound: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 48))
                .foregroundStyle(theme.inkMuted)
            Text("\"\(stickerID)\" isn't in the checklist yet.")
                .bodyStyle(size: 15)
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Save

    private func save(_ sticker: Sticker) {
        if let record = sticker.collection {
            record.quantityOwned += 1
            record.updatedAt = .now
        } else {
            context.insert(UserCollection(
                userID: "",
                stickerID: sticker.id,
                quantityOwned: 1,
                firstAcquiredAt: .now,
                updatedAt: .now
            ))
        }
        try? context.save()
        syncEngine.syncAfterWrite(context: context)
        dismiss()
    }
}
