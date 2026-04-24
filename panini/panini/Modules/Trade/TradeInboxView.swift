import SwiftUI

/// Trade inbox — placeholder.
struct TradeInboxView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text("Trades")
                .displayStyle(size: 40)
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TradeInboxView()
    }
}
