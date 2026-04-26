import SwiftUI
import SwiftData
import UIKit

// MARK: - ScanConfirmView

struct ScanConfirmView: View {
    /// Either a full sticker ID ("FRA-20") or a country code from front-scan ("FRA").
    let stickerID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(SyncEngine.self) private var syncEngine

    @AppStorage("revealsEnabled") private var revealsEnabled: Bool = true

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @State private var resolvedID: String? = nil
    @State private var revealSticker: Sticker? = nil
    @State private var duplicateAdded = false
    @State private var showManualAdd = false

    // MARK: - Derived state

    /// The sticker to display — either the resolved pick or the direct full-ID match.
    private var sticker: Sticker? {
        let id = resolvedID ?? stickerID
        return allStickers.first { $0.id == id }
    }

    /// True when stickerID carries no "-", meaning parseFront returned a country code.
    private var isCountryMode: Bool {
        !stickerID.contains("-") && resolvedID == nil
    }

    /// All stickers for the country when in country mode.
    private var countryStickers: [Sticker] {
        allStickers.filter { $0.countryCode == stickerID }
    }

    private var alreadyOwned: Bool { (sticker?.collection?.quantityOwned ?? 0) > 0 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if duplicateAdded {
                    duplicateFeedback
                } else if isCountryMode {
                    countryPicker
                } else if let sticker {
                    confirmContent(sticker)
                } else {
                    notFound
                }
            }
            .background(theme.bg)
            .navigationTitle(isCountryMode ? "Which player?" : "Add sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isCountryMode ? "Cancel" : "Scan again") { dismiss() }
                        .bodyStyle(size: 15)
                }
            }
            .navigationDestination(item: $revealSticker) { s in
                StickerRevealView(sticker: s, onConfirm: {
                    actualSave(s)
                    dismiss()
                })
                .navigationBarBackButtonHidden()
            }
        }
    }

    // MARK: - Country picker (front-scan mode)

    private var countryPicker: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Text("Front scan matched \(countryStickers.first?.nationalTeam ?? stickerID). Tap the right player.")
                    .bodyStyle(size: 14)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                ForEach(countryStickers, id: \.id) { s in
                    Button { resolvedID = s.id } label: {
                        countryRow(s)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func countryRow(_ s: Sticker) -> some View {
        let preview = UserCollection(userID: "", stickerID: s.id, quantityOwned: 1)
        return HStack(spacing: 14) {
            StickerCard(sticker: s, collection: preview, width: 60)

            VStack(alignment: .leading, spacing: 3) {
                if let name = s.playerName {
                    Text(name)
                        .bodyStyle(size: 15, weight: .medium)
                        .foregroundStyle(theme.ink)
                }
                if let pos = s.position {
                    Text(pos)
                        .bodyStyle(size: 13)
                        .foregroundStyle(theme.inkMuted)
                }
                Text(s.id)
                    .monoStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Single sticker confirm

    @ViewBuilder
    private func confirmContent(_ s: Sticker) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                heroCard(s)
                infoSection(s)
                if alreadyOwned { duplicateNotice }
                addButton(s)
            }
            .padding(24)
        }
    }

    private func heroCard(_ s: Sticker) -> some View {
        let preview = UserCollection(userID: "", stickerID: s.id, quantityOwned: 1)
        return StickerCard(sticker: s, collection: preview, width: 180)
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    private func infoSection(_ s: Sticker) -> some View {
        VStack(spacing: 6) {
            if let name = s.playerName {
                Text(name)
                    .displayStyle(size: 26)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                Text(s.nationalTeam)
                    .bodyStyle(size: 14, weight: .medium)
                    .foregroundStyle(theme.inkSoft)
                if let pos = s.position {
                    Text("·").foregroundStyle(theme.inkMuted)
                    Text(pos).bodyStyle(size: 14).foregroundStyle(theme.inkMuted)
                }
            }
            Text(s.id)
                .monoStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 2)
        }
    }

    private var duplicateNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.on.square")
            Text("Already in your collection — this will be a duplicate")
                .bodyStyle(size: 13)
        }
        .foregroundStyle(theme.inkSoft)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.chip, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func addButton(_ s: Sticker) -> some View {
        Button { save(s) } label: {
            Text(alreadyOwned ? "Add duplicate" : "Add to collection")
                .bodyStyle(size: 17, weight: .semibold)
                .foregroundStyle(theme.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Duplicate feedback screen

    private var duplicateFeedback: some View {
        VStack(spacing: 0) {
            Spacer()

            if let s = sticker {
                let count = s.collection?.quantityOwned ?? 2
                let preview = UserCollection(userID: "", stickerID: s.id, quantityOwned: count)

                StickerCard(sticker: s, collection: preview, width: 150)
                    .padding(.bottom, 28)

                Text("×\(count)")
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundStyle(theme.ink)

                if let name = s.playerName {
                    Text(name)
                        .bodyStyle(size: 17, weight: .medium)
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 6)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Now available to trade")
                }
                .bodyStyle(size: 14, weight: .medium)
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Not found

    private var notFound: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 56))
                .foregroundStyle(theme.inkMuted)
            VStack(spacing: 8) {
                Text("Sticker not recognised")
                    .displayStyle(size: 22)
                    .foregroundStyle(theme.ink)
                Text("\"\(stickerID)\" isn't in the checklist yet.")
                    .bodyStyle(size: 14)
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                showManualAdd = true
            } label: {
                Text("Search manually")
                    .bodyStyle(size: 15, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showManualAdd) { ManualAddView() }
    }

    // MARK: - Save

    private func save(_ s: Sticker) {
        if let record = s.collection {
            record.quantityOwned += 1
            record.updatedAt = .now
            try? context.save()
            syncEngine.syncAfterWrite(context: context)

            withAnimation { duplicateAdded = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { dismiss() }
        } else {
            if revealsEnabled {
                revealSticker = s
            } else {
                actualSave(s)
                dismiss()
            }
        }
    }

    private func actualSave(_ s: Sticker) {
        let uc = UserCollection(
            userID: "",
            stickerID: s.id,
            quantityOwned: 1,
            firstAcquiredAt: .now,
            updatedAt: .now
        )
        context.insert(uc)
        s.collection = uc
        try? context.save()
        syncEngine.syncAfterWrite(context: context)
    }
}
