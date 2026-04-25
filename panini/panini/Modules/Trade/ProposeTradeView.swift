import SwiftUI
import SwiftData

// MARK: - PickerMode

private enum PickerMode {
    case offer, request
}

// MARK: - ProposeTradeView

struct ProposeTradeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TradeService.self) private var tradeService
    @Environment(SyncEngine.self) private var syncEngine

    @Query(sort: [SortDescriptor(\Sticker.countryCode), SortDescriptor(\Sticker.stickerNumber)])
    private var allStickers: [Sticker]

    @Query private var friendships: [Friendship]

    @State private var selectedFriendID: String
    @State private var offeredIDs: [String]
    @State private var requestedIDs: [String]
    @State private var pickerMode: PickerMode?
    @State private var showFriendPicker = false
    @State private var isSending = false
    @State private var showConfirmation = false
    @State private var sendError: String?

    init(friendID: String, offeredStickerIDs: [String] = [], requestedStickerIDs: [String] = []) {
        self._selectedFriendID = State(initialValue: friendID)
        self._offeredIDs = State(initialValue: offeredStickerIDs)
        self._requestedIDs = State(initialValue: requestedStickerIDs)
    }

    // MARK: - Derived

    private var offeredStickers: [Sticker] {
        let ids = Set(offeredIDs)
        return allStickers.filter { ids.contains($0.id) }
    }

    private var requestedStickers: [Sticker] {
        let ids = Set(requestedIDs)
        return allStickers.filter { ids.contains($0.id) }
    }

    private var availableDupes: [Sticker] {
        allStickers.filter {
            ($0.collection?.quantityOwned ?? 0) > 1
            && !($0.collection?.blacklisted ?? false)
            && !offeredIDs.contains($0.id)
        }
    }

    private var allRequestableStickers: [Sticker] {
        allStickers.filter { !requestedIDs.contains($0.id) }
    }

    private var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == "accepted" }
    }

    private var selectedFriendName: String? {
        acceptedFriends.first(where: { $0.friendID == selectedFriendID })
            .map { $0.friendUsername.isEmpty ? $0.friendHandle : $0.friendUsername }
    }

    private var fairnessLabel: String {
        let o = offeredIDs.count
        let r = requestedIDs.count
        guard o > 0 || r > 0 else { return "" }
        if o == r { return "Fair trade" }
        if o > r  { return "Generous offer" }
        return "Uneven — you receive more"
    }

    private var fairnessColor: Color {
        let o = offeredIDs.count
        let r = requestedIDs.count
        if o == r { return theme.success }
        if o > r  { return theme.primary }
        return Color(hex: "E67E22")
    }

    private var canSend: Bool {
        !selectedFriendID.isEmpty && !offeredIDs.isEmpty && !requestedIDs.isEmpty && !isSending
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                friendRow

                tradeSection(
                    title: "You're offering",
                    subtitle: "\(offeredStickers.count) sticker\(offeredStickers.count == 1 ? "" : "s")",
                    stickers: offeredStickers,
                    accentColor: theme.primary,
                    onAdd: { pickerMode = .offer },
                    onRemove: { id in offeredIDs.removeAll { $0 == id } }
                )

                divider

                tradeSection(
                    title: "You're requesting",
                    subtitle: "\(requestedStickers.count) sticker\(requestedStickers.count == 1 ? "" : "s")",
                    stickers: requestedStickers,
                    accentColor: Color(hex: "2196F3"),
                    onAdd: { pickerMode = .request },
                    onRemove: { id in requestedIDs.removeAll { $0 == id } }
                )

                if !fairnessLabel.isEmpty {
                    fairnessChip
                }

                if let error = sendError {
                    Text(error)
                        .bodyStyle(size: 13)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(theme.bg)
        .navigationTitle("Propose Trade")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickerMode) { mode in
            StickerPickerSheet(
                mode: mode,
                stickers: mode == .offer ? availableDupes : allRequestableStickers,
                onConfirm: { selected in
                    if mode == .offer {
                        offeredIDs.append(contentsOf: selected.filter { !offeredIDs.contains($0) })
                    } else {
                        requestedIDs.append(contentsOf: selected.filter { !requestedIDs.contains($0) })
                    }
                }
            )
        }
        .sheet(isPresented: $showFriendPicker) {
            FriendPickerSheet(friends: acceptedFriends, onSelect: { selectedFriendID = $0 })
        }
        .alert("Trade proposal sent!", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your friend will be notified and can accept or decline.")
        }
    }

    // MARK: - Friend row

    private var friendRow: some View {
        Button { showFriendPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selectedFriendID.isEmpty ? theme.inkMuted : theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("To")
                        .monoStyle(size: 10)
                        .foregroundStyle(theme.inkMuted)
                        .tracking(1.2)
                    Text(selectedFriendName ?? "Select a friend")
                        .bodyStyle(size: 15, weight: .medium)
                        .foregroundStyle(selectedFriendID.isEmpty ? theme.inkMuted : theme.ink)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(16)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trade section

    private func tradeSection(
        title: String,
        subtitle: String,
        stickers: [Sticker],
        accentColor: Color,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .bodyStyle(size: 15, weight: .semibold)
                        .foregroundStyle(theme.ink)
                    Text(subtitle)
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stickers, id: \.id) { sticker in
                        ZStack(alignment: .topTrailing) {
                            StickerCard(sticker: sticker, collection: sticker.collection, width: 88)
                            Button {
                                onRemove(sticker.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(theme.inkMuted)
                                    .background(Circle().fill(theme.bg))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }

                    Button(action: onAdd) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(accentColor)
                            Text("Add")
                                .bodyStyle(size: 11)
                                .foregroundStyle(accentColor)
                        }
                        .frame(width: 88, height: 110)
                        .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(theme.chip).frame(height: 1)
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.inkMuted)
            Rectangle().fill(theme.chip).frame(height: 1)
        }
    }

    private var fairnessChip: some View {
        HStack(spacing: 6) {
            Circle().fill(fairnessColor).frame(width: 8, height: 8)
            Text(fairnessLabel)
                .bodyStyle(size: 13, weight: .medium)
                .foregroundStyle(fairnessColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(fairnessColor.opacity(0.1), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    private var sendButton: some View {
        Button {
            Task { await send() }
        } label: {
            Group {
                if isSending {
                    ProgressView().tint(theme.primaryInk)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Send trade request")
                    }
                    .bodyStyle(size: 16, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSend ? theme.primary : theme.chip,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(!canSend)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func send() async {
        isSending = true
        sendError = nil
        do {
            try await tradeService.createTrade(
                recipientID: selectedFriendID,
                offeredStickerIDs: offeredIDs,
                requestedStickerIDs: requestedIDs
            )
            syncEngine.syncAfterWrite(context: context)
            showConfirmation = true
        } catch {
            sendError = "Couldn't send — please try again."
        }
        isSending = false
    }
}

// MARK: - PickerMode + Identifiable

extension PickerMode: Identifiable {
    var id: Int { self == .offer ? 0 : 1 }
}

// MARK: - StickerPickerSheet

private struct StickerPickerSheet: View {
    let mode: PickerMode
    let stickers: [Sticker]
    let onConfirm: ([String]) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selected = Set<String>()

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(stickers, id: \.id) { sticker in
                        ZStack(alignment: .topTrailing) {
                            StickerCard(sticker: sticker, collection: sticker.collection, width: 96)
                                .opacity(selected.contains(sticker.id) ? 0.75 : 1)

                            if selected.contains(sticker.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(theme.primary)
                                    .background(Circle().fill(.white))
                                    .offset(x: 6, y: -6)
                            }
                        }
                        .onTapGesture {
                            if selected.contains(sticker.id) {
                                selected.remove(sticker.id)
                            } else {
                                selected.insert(sticker.id)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.bg)
            .navigationTitle(mode == .offer ? "Choose to offer" : "Choose to request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selected.isEmpty ? "" : "(\(selected.count))")") {
                        onConfirm(Array(selected))
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                    .foregroundStyle(theme.primary)
                }
            }
            .overlay {
                if stickers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: mode == .offer ? "doc.on.doc" : "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(theme.inkMuted)
                        Text(mode == .offer
                             ? "No duplicate stickers available to offer"
                             : "No stickers available to request")
                            .bodyStyle(size: 14)
                            .foregroundStyle(theme.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
    }
}

// MARK: - FriendPickerSheet

private struct FriendPickerSheet: View {
    let friends: [Friendship]
    let onSelect: (String) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(friends) { f in
                    Button {
                        onSelect(f.friendID)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            let initial = f.friendHandle.first.map(String.init) ?? "?"
                            Text(initial.uppercased())
                                .bodyStyle(size: 15, weight: .semibold)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "C8511B"), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.friendUsername.isEmpty ? f.friendHandle : f.friendUsername)
                                    .bodyStyle(size: 15, weight: .medium)
                                    .foregroundStyle(theme.ink)
                                Text("@\(f.friendHandle)")
                                    .bodyStyle(size: 13)
                                    .foregroundStyle(theme.inkMuted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.bg)
            .navigationTitle("Choose friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if friends.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 36))
                            .foregroundStyle(theme.inkMuted)
                        Text("No friends to trade with yet")
                            .bodyStyle(size: 14)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Sticker.self, UserCollection.self,
        configurations: config
    )
    let s1 = Sticker(id: "ARG-10", countryCode: "ARG", stickerNumber: 10, type: "player",
                     playerName: "L. Messi", position: "FWD", nationalTeam: "Argentina")
    let s2 = Sticker(id: "ENG-9", countryCode: "ENG", stickerNumber: 9, type: "player",
                     playerName: "H. Kane", position: "FWD", nationalTeam: "England")
    let s3 = Sticker(id: "BRA-7", countryCode: "BRA", stickerNumber: 7, type: "player",
                     playerName: "Vinicius Jr", position: "FWD", nationalTeam: "Brazil")
    let uc1 = UserCollection(userID: "me", stickerID: "ARG-10", quantityOwned: 3)
    let uc2 = UserCollection(userID: "me", stickerID: "ENG-9", quantityOwned: 2)
    let uc3 = UserCollection(userID: "me", stickerID: "BRA-7", quantityOwned: 0, wishlisted: true)
    [s1, s2, s3].forEach { container.mainContext.insert($0) }
    [uc1, uc2, uc3].forEach { container.mainContext.insert($0) }
    s1.collection = uc1; s2.collection = uc2; s3.collection = uc3
    try? container.mainContext.save()

    return NavigationStack {
        ProposeTradeView(
            friendID: "friend-abc",
            offeredStickerIDs: ["ARG-10"],
            requestedStickerIDs: ["BRA-7"]
        )
    }
    .modelContainer(container)
    .environment(TradeService(apiClient: APIClient()))
    .environment(SyncEngine(apiClient: APIClient()))
}
