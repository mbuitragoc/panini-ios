import Foundation
import Observation
import SwiftData

// MARK: - Sync response types (API shape)

private struct SyncResponse: Decodable {
    let collections: [CollectionSyncItem]
    let trades: [TradeSyncItem]
    let friendships: [FriendshipSyncItem]
    let syncedAt: Date
}

private struct CollectionSyncItem: Decodable {
    let userId: String
    let stickerId: String
    let quantityOwned: Int
    let wishlisted: Bool
    let blacklisted: Bool
    let firstAcquiredAt: Date?
    let updatedAt: Date
}

private struct TradeSyncItem: Decodable {
    let id: String
    let proposerId: String
    let recipientId: String
    let status: String
    let offeredStickers: [String]
    let requestedStickers: [String]
    let proposedAt: Date
    let resolvedAt: Date?
    let completedAt: Date?
    let updatedAt: Date
}

private struct FriendshipSyncItem: Decodable {
    let friendId: String
    let friendUsername: String
    let friendHandle: String
    let friendOwnedCount: Int
    let status: String
    let updatedAt: Date
}

// MARK: - SyncEngine

/// Observable service that orchestrates background sync with the remote API.
@Observable
final class SyncEngine {
    private(set) var isSyncing = false

    private let apiClient: APIClient
    private let lastSyncedAtKey = "sync.lastSyncedAt"

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Performs a delta sync. Sends ?since= when a prior sync timestamp exists.
    func sync(context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let endpoint: String
        if let since = UserDefaults.standard.string(forKey: lastSyncedAtKey),
           let encoded = since.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            endpoint = "/v1/sync?since=\(encoded)"
        } else {
            endpoint = "/v1/sync"
        }

        do {
            let response: SyncResponse = try await apiClient.request(endpoint)
            await applySync(response, context: context)
            UserDefaults.standard.set(
                ISO8601DateFormatter().string(from: response.syncedAt),
                forKey: lastSyncedAtKey
            )
        } catch {
            // Network failures are silent — next foreground entry retries.
        }
    }

    /// Hook for write paths (e.g., adding a sticker) to trigger an immediate sync.
    func syncAfterWrite(context: ModelContext) {
        Task { await sync(context: context) }
    }

    // MARK: - Diff application

    @MainActor
    private func applySync(_ response: SyncResponse, context: ModelContext) async {
        applyCollections(response.collections, context: context)
        applyTrades(response.trades, context: context)
        applyFriendships(response.friendships, context: context)
        try? context.save()
    }

    @MainActor
    private func applyCollections(_ items: [CollectionSyncItem], context: ModelContext) {
        let locals = (try? context.fetch(FetchDescriptor<UserCollection>())) ?? []
        let localMap = Dictionary(uniqueKeysWithValues: locals.map { ($0.stickerID, $0) })
        let localUpdatedAts = localMap.mapValues { $0.updatedAt }

        let remote = items.map {
            SyncDiffEngine.CollectionRecord(
                stickerID: $0.stickerId,
                quantityOwned: $0.quantityOwned,
                wishlisted: $0.wishlisted,
                blacklisted: $0.blacklisted,
                firstAcquiredAt: $0.firstAcquiredAt,
                updatedAt: $0.updatedAt
            )
        }

        let diff = SyncDiffEngine.applyCollections(remote: remote, localUpdatedAts: localUpdatedAts)

        for record in diff.toInsert {
            context.insert(UserCollection(
                userID: items.first(where: { $0.stickerId == record.stickerID })?.userId ?? "",
                stickerID: record.stickerID,
                quantityOwned: record.quantityOwned,
                wishlisted: record.wishlisted,
                blacklisted: record.blacklisted,
                firstAcquiredAt: record.firstAcquiredAt,
                updatedAt: record.updatedAt
            ))
        }

        for record in diff.toUpdate {
            guard let local = localMap[record.stickerID] else { continue }
            local.quantityOwned = record.quantityOwned
            local.wishlisted = record.wishlisted
            local.blacklisted = record.blacklisted
            local.firstAcquiredAt = record.firstAcquiredAt
            local.updatedAt = record.updatedAt
        }
    }

    @MainActor
    private func applyTrades(_ items: [TradeSyncItem], context: ModelContext) {
        let locals = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let localMap = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

        let remote = items.map {
            SyncDiffEngine.TradeRecord(
                id: $0.id,
                proposerID: $0.proposerId,
                recipientID: $0.recipientId,
                status: $0.status,
                offeredStickers: $0.offeredStickers,
                requestedStickers: $0.requestedStickers,
                proposedAt: $0.proposedAt,
                resolvedAt: $0.resolvedAt,
                completedAt: $0.completedAt,
                updatedAt: $0.updatedAt
            )
        }

        let diff = SyncDiffEngine.applyTrades(remote: remote, knownIDs: Set(localMap.keys))

        for record in diff.toInsert {
            context.insert(Trade(
                id: record.id,
                proposerID: record.proposerID,
                recipientID: record.recipientID,
                status: record.status,
                offeredStickers: record.offeredStickers,
                requestedStickers: record.requestedStickers,
                proposedAt: record.proposedAt,
                resolvedAt: record.resolvedAt,
                completedAt: record.completedAt,
                updatedAt: record.updatedAt
            ))
        }

        for record in diff.toUpdate {
            guard let local = localMap[record.id] else { continue }
            local.status = record.status
            local.offeredStickers = record.offeredStickers
            local.requestedStickers = record.requestedStickers
            local.resolvedAt = record.resolvedAt
            local.completedAt = record.completedAt
            local.updatedAt = record.updatedAt
        }
    }

    @MainActor
    private func applyFriendships(_ items: [FriendshipSyncItem], context: ModelContext) {
        let locals = (try? context.fetch(FetchDescriptor<Friendship>())) ?? []
        let localMap = Dictionary(uniqueKeysWithValues: locals.map { ($0.friendID, $0) })

        let remote = items.map {
            SyncDiffEngine.FriendshipRecord(
                friendID: $0.friendId,
                friendUsername: $0.friendUsername,
                friendHandle: $0.friendHandle,
                friendOwnedCount: $0.friendOwnedCount,
                status: $0.status,
                updatedAt: $0.updatedAt
            )
        }

        let diff = SyncDiffEngine.applyFriendships(remote: remote, knownFriendIDs: Set(localMap.keys))

        for record in diff.toInsert {
            context.insert(Friendship(
                userID: "",   // userID is not in the sync record; set at write time
                friendID: record.friendID,
                friendUsername: record.friendUsername,
                friendHandle: record.friendHandle,
                friendOwnedCount: record.friendOwnedCount,
                status: record.status,
                updatedAt: record.updatedAt
            ))
        }

        for record in diff.toUpdate {
            guard let local = localMap[record.friendID] else { continue }
            local.friendUsername = record.friendUsername
            local.friendHandle = record.friendHandle
            local.friendOwnedCount = record.friendOwnedCount
            local.status = record.status
            local.updatedAt = record.updatedAt
        }
    }
}
