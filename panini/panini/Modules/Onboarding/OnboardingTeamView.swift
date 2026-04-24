import SwiftUI
import SwiftData

struct OnboardingTeamView: View {
    let countryCode: String
    let teamName: String

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    @Query private var teamStickers: [Sticker]

    init(countryCode: String, teamName: String) {
        self.countryCode = countryCode
        self.teamName = teamName
        _teamStickers = Query(
            filter: #Predicate<Sticker> { $0.countryCode == countryCode },
            sort: [SortDescriptor(\.stickerNumber)]
        )
    }

    private var ownedCount: Int {
        teamStickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count
    }

    private var allOwned: Bool {
        !teamStickers.isEmpty && ownedCount == teamStickers.count
    }

    var body: some View {
        List {
            Section {
                ForEach(teamStickers, id: \.id) { sticker in
                    StickerToggleRow(sticker: sticker)
                }
            } header: {
                Text("\(ownedCount) of \(teamStickers.count) owned")
                    .monoStyle(size: 11)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .navigationTitle(teamName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(allOwned ? "Uncheck all" : "Mark all") {
                    toggleAll()
                }
                .bodyStyle(size: 14)
                .foregroundStyle(theme.primary)
            }
        }
    }

    private func toggleAll() {
        if allOwned {
            for sticker in teamStickers {
                if let record = sticker.collection {
                    record.quantityOwned = 0
                    record.updatedAt = .now
                }
            }
        } else {
            for sticker in teamStickers {
                if let record = sticker.collection {
                    if record.quantityOwned == 0 {
                        record.quantityOwned = 1
                        record.updatedAt = .now
                    }
                } else {
                    context.insert(UserCollection(
                        userID: "",
                        stickerID: sticker.id,
                        quantityOwned: 1,
                        firstAcquiredAt: .now,
                        updatedAt: .now
                    ))
                }
            }
        }
        try? context.save()
    }
}

// MARK: - StickerToggleRow

private struct StickerToggleRow: View {
    let sticker: Sticker

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    private var isOwned: Bool { (sticker.collection?.quantityOwned ?? 0) > 0 }

    var body: some View {
        Button { toggle() } label: {
            HStack(spacing: 14) {
                Image(systemName: isOwned ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOwned ? theme.primary : theme.inkMuted)
                    .animation(.easeInOut(duration: 0.15), value: isOwned)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = sticker.playerName {
                        Text(name)
                            .bodyStyle(size: 15, weight: .medium)
                            .foregroundStyle(theme.ink)
                    }
                    Text(sticker.id)
                        .monoStyle(size: 11)
                        .foregroundStyle(theme.inkMuted)
                }

                Spacer()

                if let pos = sticker.position {
                    Text(pos)
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.chip, in: Capsule())
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(theme.surface)
    }

    private func toggle() {
        if let record = sticker.collection {
            record.quantityOwned = isOwned ? 0 : 1
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
    }
}
