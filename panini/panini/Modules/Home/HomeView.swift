import SwiftUI
import SwiftData

/// Home screen — placeholder showing a grid of team tiles.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Query private var collections: [UserCollection]

    private let placeholderTeams = ["ARG", "BRA", "FRA", "ENG", "ESP", "GER", "POR", "MEX"]
    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Home")
                    .displayStyle(size: 40)
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(placeholderTeams, id: \.self) { code in
                        teamTile(code)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func teamTile(_ code: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accent.opacity(0.15))
                .frame(height: 80)

            Text(code)
                .monoStyle(size: 13)
                .foregroundStyle(theme.accent)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: UserCollection.self, inMemory: true)
}
