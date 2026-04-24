import SwiftUI

/// Detail screen for a single sticker.
struct StickerDetailView: View {
    let sticker: Sticker
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text(sticker.playerName ?? sticker.id)
                .displayStyle(size: 36)
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)

            Text(sticker.id)
                .monoStyle(size: 13)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
