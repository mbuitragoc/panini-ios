import SwiftUI
import SwiftData

// MARK: - Collection update types

private struct CollectionUpdateRequest: Encodable {
    var wishlisted: Bool?
    var blacklisted: Bool?
}

private struct CollectionUpdateResponse: Decodable {}

private struct MissingRatingsRequest: Encodable {
    var sticker_ids: [String]
}

// MARK: - StickerDetailView

struct StickerDetailView: View {
    let sticker: Sticker

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(APIClient.self) private var apiClient

    private var isOwned: Bool { (sticker.collection?.quantityOwned ?? 0) > 0 }
    private var quantity: Int { sticker.collection?.quantityOwned ?? 0 }
    private var isWishlisted: Bool { sticker.collection?.wishlisted == true }
    private var isBlacklisted: Bool { sticker.collection?.blacklisted == true }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSection
            }
        }
        .background(theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .task { reportMissingRatingIfNeeded() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Team gradient backdrop
            let colors = teamGradient(for: sticker.countryCode)
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 260)
                .overlay(alignment: .bottom) {
                    // Fade into bg
                    LinearGradient(
                        colors: [.clear, theme.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }

            // Tilted sticker card
            StickerCard(sticker: sticker, collection: sticker.collection, width: 190)
                .rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 10)
                .offset(y: 50)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Name + ID
            VStack(alignment: .center, spacing: 6) {
                if let name = sticker.playerName {
                    Text(name)
                        .displayStyle(size: 28)
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.center)
                }
                Text(sticker.id)
                    .monoStyle(size: 13)
                    .foregroundStyle(theme.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)   // space for card bleed

            if sticker.type == "player" {
                if let rating = sticker.rating {
                    ovrStrip(rating: rating)
                    playerStatsCard(rating: rating)
                }
            }

            ownershipStrip
            metadataTable
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    // MARK: - OVR strip

    private func ovrStrip(rating: PlayerRating) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(rating.overall)")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(rating.rarityColor)
                Text("OVR")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            rarityBadge(rating: rating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func rarityBadge(rating: PlayerRating) -> some View {
        Text(rating.rarity.uppercased())
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(rating.rarityColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rating.rarityColor.opacity(0.4), lineWidth: 1.5)
            )
    }

    // MARK: - Player stats card

    private func playerStatsCard(rating: PlayerRating) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Field + radar side by side when nation position is available
            if let pos = rating.nationPosition, !pos.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    fieldPositionCard(rating: rating, position: pos)
                    radarCard(rating: rating)
                }
            } else {
                radarCard(rating: rating)
                    .frame(maxWidth: .infinity)
            }

            // Play styles
            if !rating.playStyles.isEmpty {
                playStylesRow(styles: rating.playStyles)
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func fieldPositionCard(rating: PlayerRating, position: String) -> some View {
        VStack(spacing: 8) {
            FieldPositionView(
                position: position,
                jerseyNumber: rating.nationJerseyNumber,
                accentColor: rating.rarityColor
            )
            .frame(width: 110, height: 155)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(position)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
        }
    }

    private func radarCard(rating: PlayerRating) -> some View {
        RadarChartView(
            stats: rating.radarStats,
            accentColor: rating.rarityColor,
            chartSize: 200
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private func playStylesRow(styles: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(styles, id: \.self) { style in
                    Text(style)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.chip, in: Capsule())
                }
            }
        }
    }

    // MARK: - Ownership strip

    private var ownershipStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: isOwned ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 22))
                .foregroundStyle(isOwned ? theme.success : theme.inkMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(isOwned ? "In your collection" : "Not in your collection")
                    .bodyStyle(size: 15, weight: .medium)
                    .foregroundStyle(isOwned ? theme.ink : theme.inkSoft)

                if isOwned, let date = sticker.collection?.firstAcquiredAt {
                    Text("First added \(date.formatted(date: .abbreviated, time: .omitted))")
                        .bodyStyle(size: 12)
                        .foregroundStyle(theme.inkMuted)
                }
            }

            Spacer()

            if isOwned {
                Text("×\(quantity)")
                    .monoStyle(size: 14)
                    .foregroundStyle(quantity > 1 ? Color(hex: "C8933A") : theme.inkMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (quantity > 1 ? Color(hex: "FFF3CD") : theme.chip),
                        in: Capsule()
                    )
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Metadata table

    private var metadataTable: some View {
        VStack(spacing: 0) {
            metaRow(label: "Sticker ID", value: sticker.id, mono: true)
            Divider().padding(.leading, 16)
            metaRow(label: "Nation", value: sticker.nationalTeam)
            if let pos = sticker.position {
                Divider().padding(.leading, 16)
                metaRow(label: "Position", value: pos)
            }
            Divider().padding(.leading, 16)
            metaRow(label: "Rarity", value: sticker.rarity.capitalized)
            if let club = sticker.club {
                Divider().padding(.leading, 16)
                metaRow(label: "Club", value: club)
            }
            if let h = sticker.height {
                Divider().padding(.leading, 16)
                metaRow(label: "Height", value: "\(Int(h)) cm")
            }
            if let age = ageText {
                Divider().padding(.leading, 16)
                metaRow(label: "Age", value: age)
            }
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metaRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .bodyStyle(size: 14)
                .foregroundStyle(theme.inkSoft)
            Spacer()
            if mono {
                Text(value).monoStyle(size: 13).foregroundStyle(theme.ink)
            } else {
                Text(value).bodyStyle(size: 14).foregroundStyle(theme.ink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var ageText: String? {
        guard let dob = sticker.dob else { return nil }
        let years = Calendar.current.dateComponents([.year], from: dob, to: .now).year ?? 0
        return "\(years) yrs"
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !isOwned {
                wishlistButton
            }

            if isOwned {
                Button { markDuplicate() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.square.on.square")
                        Text("Mark duplicate")
                    }
                    .bodyStyle(size: 16, weight: .semibold)
                    .foregroundStyle(theme.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.primary, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            if quantity > 1 {
                blacklistButton
            }

            NavigationLink {
                ProposeTradeView(
                    friendID: "",
                    offeredStickerIDs: quantity > 1 && !isBlacklisted ? [sticker.id] : [],
                    requestedStickerIDs: isWishlisted ? [sticker.id] : []
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Propose trade")
                }
                .bodyStyle(size: 16, weight: .semibold)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.chip, lineWidth: 1))
            }
        }
    }

    private var wishlistButton: some View {
        Button { toggleWishlist() } label: {
            HStack(spacing: 8) {
                Image(systemName: isWishlisted ? "bookmark.fill" : "bookmark")
                Text(isWishlisted ? "Remove from wishlist" : "Add to wishlist")
            }
            .bodyStyle(size: 16, weight: .semibold)
            .foregroundStyle(isWishlisted ? theme.primaryInk : theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isWishlisted ? theme.primary : theme.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.chip, lineWidth: isWishlisted ? 0 : 1)
            )
        }
    }

    private var blacklistButton: some View {
        Button { toggleBlacklist() } label: {
            HStack(spacing: 8) {
                Image(systemName: isBlacklisted ? "nosign" : "nosign")
                Text(isBlacklisted ? "Remove from blacklist" : "Blacklist duplicate")
            }
            .bodyStyle(size: 16, weight: .semibold)
            .foregroundStyle(isBlacklisted ? .white : theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isBlacklisted ? Color(hex: "C0392B") : theme.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.chip, lineWidth: isBlacklisted ? 0 : 1)
            )
        }
    }

    // MARK: - Mark duplicate

    private func markDuplicate() {
        if let record = sticker.collection {
            record.quantityOwned += 1
            record.updatedAt = .now
        } else {
            let uc = UserCollection(
                userID: "",
                stickerID: sticker.id,
                quantityOwned: 1,
                firstAcquiredAt: .now,
                updatedAt: .now
            )
            context.insert(uc)
            sticker.collection = uc
        }
        try? context.save()
        syncEngine.syncAfterWrite(context: context)
    }

    // MARK: - Wishlist / Blacklist

    private func toggleWishlist() {
        let newValue = !isWishlisted
        if let record = sticker.collection {
            record.wishlisted = newValue
            record.updatedAt = .now
        } else {
            let uc = UserCollection(
                userID: "",
                stickerID: sticker.id,
                quantityOwned: 0,
                wishlisted: newValue,
                updatedAt: .now
            )
            context.insert(uc)
            sticker.collection = uc
        }
        try? context.save()
        Task {
            let body = CollectionUpdateRequest(wishlisted: newValue)
            let _: CollectionUpdateResponse? = try? await apiClient.request(
                "/v1/collections/\(sticker.id)",
                method: "PUT",
                body: body
            )
        }
    }

    private func toggleBlacklist() {
        guard let record = sticker.collection else { return }
        let newValue = !record.blacklisted
        record.blacklisted = newValue
        record.updatedAt = .now
        try? context.save()
        Task {
            let body = CollectionUpdateRequest(blacklisted: newValue)
            let _: CollectionUpdateResponse? = try? await apiClient.request(
                "/v1/collections/\(sticker.id)",
                method: "PUT",
                body: body
            )
        }
    }

    // MARK: - Missing rating report

    private func reportMissingRatingIfNeeded() {
        guard sticker.type == "player", sticker.rating == nil else { return }
        Task {
            let body = MissingRatingsRequest(sticker_ids: [sticker.id])
            let _: CollectionUpdateResponse? = try? await apiClient.request(
                "/v1/admin/missing-ratings",
                method: "POST",
                body: body
            )
        }
    }
}
