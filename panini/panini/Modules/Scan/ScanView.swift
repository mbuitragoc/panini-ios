import SwiftUI

/// Scan screen — placeholder pending camera integration in slice #5.
struct ScanView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Text("Scan")
                .displayStyle(size: 40)
                .foregroundStyle(theme.ink)

            Text("Camera coming in slice #5")
                .bodyStyle(size: 16)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ScanView()
    }
}
