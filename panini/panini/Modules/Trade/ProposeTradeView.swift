import SwiftUI

/// Propose trade screen — placeholder.
struct ProposeTradeView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text("Propose trade")
                .displayStyle(size: 36)
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
        ProposeTradeView()
    }
}
