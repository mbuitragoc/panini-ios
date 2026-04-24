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

    @State private var tab: AddFriendTab = .nearby
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var sentTo: Set<String> = []
    @State private var searchTask: Task<Void, Never>?
    @State private var nearbySession = NearbySessionManager()

    private enum AddFriendTab: String, CaseIterable {
        case nearby  = "Nearby"
        case qr      = "QR Code"
        case invite  = "Invite"
        case search  = "Search"
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
                case .nearby: nearbyTab
                case .qr:     qrTab
                case .invite: inviteTab
                case .search: searchTab
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
        .onAppear { startNearbyIfNeeded() }
        .onDisappear { nearbySession.stop() }
        .onChange(of: tab) { _, new in
            if new == .nearby { startNearbyIfNeeded() }
        }
    }

    // MARK: - Nearby tab

    @ViewBuilder
    private var nearbyTab: some View {
        switch nearbySession.sessionState {
        case .unavailable:
            unavailableState

        case .idle, .searching:
            searchingState

        case .ranging(let handle, let distance):
            rangingState(handle: handle, distance: distance)

        case .tapDetected(let handle, _):
            successState(handle: handle)
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(theme.inkMuted)
            Text("Nearby tap not available")
                .displayStyle(size: 18)
                .foregroundStyle(theme.ink)
            Text("This feature requires an iPhone 11 or later with the U1 chip. Use QR or Search instead.")
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var searchingState: some View {
        VStack(spacing: 24) {
            PulseView(color: theme.primary)
                .frame(width: 160, height: 160)

            VStack(spacing: 8) {
                Text("Hold phones close together")
                    .displayStyle(size: 18)
                    .foregroundStyle(theme.ink)
                Text("Both friends need to have this screen open")
                    .bodyStyle(size: 14)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func rangingState(handle: String, distance: Float) -> some View {
        let pct = max(0, min(1, (1.0 - Double(distance) / 1.5)))
        return VStack(spacing: 28) {
            ZStack {
                PulseView(color: distance < 0.4 ? .green : theme.primary)
                    .frame(width: 160, height: 160)

                VStack(spacing: 4) {
                    Text(String(format: "%.1fm", distance))
                        .displayStyle(size: 28)
                        .foregroundStyle(distance < 0.25 ? .green : theme.ink)
                    Text("away")
                        .bodyStyle(size: 13)
                        .foregroundStyle(theme.inkMuted)
                }
            }

            VStack(spacing: 10) {
                Text("@\(handle)")
                    .bodyStyle(size: 15, weight: .semibold)
                    .foregroundStyle(theme.ink)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.chip).frame(height: 6)
                        Capsule().fill(distance < 0.25 ? Color.green : theme.primary)
                            .frame(width: geo.size.width * pct, height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 40)

                Text(distance < 0.25 ? "Keep still — connecting…" : "Move closer to connect")
                    .bodyStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .animation(.easeInOut(duration: 0.3), value: distance)
    }

    private func successState(handle: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))

            VStack(spacing: 6) {
                Text("Friend request sent!")
                    .displayStyle(size: 22)
                    .foregroundStyle(theme.ink)
                Text("@\(handle)")
                    .bodyStyle(size: 15)
                    .foregroundStyle(theme.inkMuted)
            }

            Button("Done") { dismiss() }
                .bodyStyle(size: 16, weight: .semibold)
                .foregroundStyle(theme.primaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: true)
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
                Text("Let a friend scan this to send you a request")
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

    // MARK: - Invite link tab

    private var inviteTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(theme.primary)

            VStack(spacing: 6) {
                Text("Share your invite link")
                    .displayStyle(size: 18)
                    .foregroundStyle(theme.ink)
                Text("Anyone who opens your link can send you a friend request.")
                    .bodyStyle(size: 14)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            if let uid = authService.currentUserID,
               let url = URL(string: "panini://add-friend/\(uid)") {
                ShareLink(item: url, subject: Text("Add me on Panini!"),
                          message: Text("Tap this link to add me as a friend on the Panini sticker app.")) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share invite link")
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
                if isSearching { ProgressView().scaleEffect(0.8) }
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
                    SearchResultRow(user: user, sent: sentTo.contains(user.id)) {
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

    private func startNearbyIfNeeded() {
        guard let uid = authService.currentUserID else { return }
        // Extract handle from auth — fall back to uid prefix
        let handle = uid // FriendsView has authService.currentUserID; actual handle stored in sync
        if case .idle = nearbySession.sessionState {
            nearbySession.onFriendDiscovered = { friendID in
                Task {
                    try? await friendService.sendFriendRequest(friendID: friendID)
                    syncEngine.syncAfterWrite(context: context)
                }
            }
            nearbySession.start(userID: uid, handle: handle)
        }
    }

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else { searchResults = []; return }
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
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - PulseView

private struct PulseView: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(color.opacity(animate ? 0 : 0.4), lineWidth: 2)
                    .scaleEffect(animate ? 1.5 + Double(i) * 0.3 : 1)
                    .animation(
                        .easeOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.4),
                        value: animate
                    )
            }
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 80, height: 80)
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 32))
                .foregroundStyle(color)
        }
        .onAppear { animate = true }
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
