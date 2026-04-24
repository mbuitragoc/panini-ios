import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

// MARK: - AddFriendSheet

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var authService
    @Environment(FriendService.self) private var friendService
    @Environment(SyncEngine.self) private var syncEngine

    @State private var tab: AddFriendTab = .qr
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var sentTo: Set<String> = []
    @State private var searchTask: Task<Void, Never>?

    private enum AddFriendTab: String, CaseIterable {
        case qr = "QR Code"
        case airdrop = "AirDrop"
        case search = "Search"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Method", selection: $tab) {
                    ForEach(AddFriendTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                switch tab {
                case .qr:      qrTab
                case .airdrop: airdropTab
                case .search:  searchTab
                }

                Spacer()
            }
            .background(theme.bg)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .bodyStyle(size: 15)
                        .foregroundStyle(theme.primary)
                }
            }
        }
    }

    // MARK: - QR tab

    private var qrTab: some View {
        VStack(spacing: 20) {
            if let uid = authService.currentUserID {
                let deepLink = "panini://add-friend/\(uid)"

                if let image = generateQR(from: deepLink) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                }

                Text("Let a friend scan this code to send you a request")
                    .bodyStyle(size: 14)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Sign in to show your QR code")
                    .bodyStyle(size: 14)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - AirDrop tab

    private var airdropTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplayaudio")
                .font(.system(size: 60))
                .foregroundStyle(theme.primary)

            Text("Share your link via AirDrop")
                .displayStyle(size: 18)
                .foregroundStyle(theme.ink)

            Text("The recipient will open the link and a friend request will be sent automatically.")
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let uid = authService.currentUserID,
               let url = URL(string: "panini://add-friend/\(uid)") {
                ShareLink(item: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share via AirDrop")
                    }
                    .bodyStyle(size: 16, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Search tab

    private var searchTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.inkMuted)
                TextField("Search by handle", text: $searchText)
                    .bodyStyle(size: 15)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchText) { _, new in debounceSearch(new) }
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Text("No users found")
                        .bodyStyle(size: 15)
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(.top, 40)
            } else {
                List(searchResults) { user in
                    SearchResultRow(
                        user: user,
                        sent: sentTo.contains(user.id)
                    ) {
                        sendRequest(to: user)
                    }
                    .listRowBackground(theme.surface)
                    .listRowSeparatorTint(theme.chip)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Helpers

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        searchTask = Task {
            isSearching = true
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            searchResults = (try? await friendService.searchUsers(handle: query)) ?? []
            isSearching = false
        }
    }

    private func sendRequest(to user: UserSearchResult) {
        guard !sentTo.contains(user.id) else { return }
        sentTo.insert(user.id)
        Task {
            try? await friendService.sendFriendRequest(friendID: user.id)
            syncEngine.syncAfterWrite(context: context)
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let user: UserSearchResult
    let sent: Bool
    let onSend: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            let initial = user.handle.first.map(String.init) ?? "?"
            Text(initial.uppercased())
                .bodyStyle(size: 16, weight: .semibold)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: "C8511B"), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username.isEmpty ? user.handle : user.username)
                    .bodyStyle(size: 15, weight: .medium)
                    .foregroundStyle(theme.ink)
                Text("@\(user.handle)")
                    .bodyStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            Button(action: onSend) {
                Text(sent ? "Sent" : "Add")
                    .bodyStyle(size: 13, weight: .semibold)
                    .foregroundStyle(sent ? theme.inkMuted : theme.primaryInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(sent ? theme.chip : theme.primary, in: Capsule())
            }
            .disabled(sent)
        }
        .padding(.vertical, 4)
    }
}
