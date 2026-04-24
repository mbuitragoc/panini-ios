import SwiftUI
import SwiftData

struct OnboardingNationsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.router) private var router
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var syncEngine

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    private var nations: [(code: String, name: String, total: Int, owned: Int)] {
        let grouped = Dictionary(grouping: allStickers, by: \.countryCode)
        return grouped.map { code, stickers in
            let name = stickers.first?.nationalTeam ?? code
            let owned = stickers.filter { ($0.collection?.quantityOwned ?? 0) > 0 }.count
            return (code: code, name: name, total: stickers.count, owned: owned)
        }
        .sorted { $0.name < $1.name }
    }

    var body: some View {
        List(nations, id: \.code) { nation in
            NavigationLink {
                OnboardingTeamView(countryCode: nation.code, teamName: nation.name)
            } label: {
                NationProgressRow(name: nation.name, owned: nation.owned, total: nation.total)
            }
            .listRowBackground(theme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .navigationTitle("Your stickers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    syncEngine.syncAfterWrite(context: context)
                    router.needsOnboarding = false
                }
                .bodyStyle(size: 15, weight: .semibold)
                .foregroundStyle(theme.primary)
            }
        }
    }
}

// MARK: - NationProgressRow

private struct NationProgressRow: View {
    let name: String
    let owned: Int
    let total: Int

    @Environment(\.theme) private var theme

    private var fraction: Double { total > 0 ? Double(owned) / Double(total) : 0 }
    private var isComplete: Bool { owned == total && total > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .bodyStyle(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(owned)/\(total)")
                    .monoStyle(size: 12)
                    .foregroundStyle(theme.inkMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.chip)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isComplete ? theme.success : theme.primary)
                        .frame(width: geo.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 6)
    }
}
