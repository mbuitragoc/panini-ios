import Foundation

// MARK: - SyncDiffEngine

/// Pure merge logic for offline-first sync. No SwiftData dependency — operates on value types only.
/// Callers are responsible for applying the returned diffs to the persistent store.
enum SyncDiffEngine {

    // MARK: - Remote record types

    struct CollectionRecord {
        let stickerID: String
        let quantityOwned: Int
        let wishlisted: Bool
        let blacklisted: Bool
        let firstAcquiredAt: Date?
        let updatedAt: Date
    }

    struct TradeRecord {
        let id: String
        let proposerID: String
        let recipientID: String
        let status: String
        let offeredStickers: [String]
        let requestedStickers: [String]
        let proposedAt: Date
        let resolvedAt: Date?
        let completedAt: Date?
        let updatedAt: Date
    }

    struct FriendshipRecord {
        let friendID: String
        let friendUsername: String
        let friendHandle: String
        let friendOwnedCount: Int
        let status: String
        let updatedAt: Date
    }

    // MARK: - Diff result types

    struct CollectionDiff {
        let toInsert: [CollectionRecord]
        let toUpdate: [CollectionRecord]
    }

    struct TradeDiff {
        let toInsert: [TradeRecord]
        let toUpdate: [TradeRecord]
    }

    struct FriendshipDiff {
        let toInsert: [FriendshipRecord]
        let toUpdate: [FriendshipRecord]
    }

    // MARK: - Merge strategies

    /// LWW (last-write-wins) by updatedAt. Remote wins only when remote.updatedAt > local.updatedAt.
    static func applyCollections(
        remote: [CollectionRecord],
        localUpdatedAts: [String: Date]
    ) -> CollectionDiff {
        var toInsert: [CollectionRecord] = []
        var toUpdate: [CollectionRecord] = []

        for record in remote {
            if let localDate = localUpdatedAts[record.stickerID] {
                if record.updatedAt > localDate {
                    toUpdate.append(record)
                }
            } else {
                toInsert.append(record)
            }
        }

        return CollectionDiff(toInsert: toInsert, toUpdate: toUpdate)
    }

    /// Server-wins: remote always overwrites local for trades.
    static func applyTrades(
        remote: [TradeRecord],
        knownIDs: Set<String>
    ) -> TradeDiff {
        var toInsert: [TradeRecord] = []
        var toUpdate: [TradeRecord] = []

        for record in remote {
            if knownIDs.contains(record.id) {
                toUpdate.append(record)
            } else {
                toInsert.append(record)
            }
        }

        return TradeDiff(toInsert: toInsert, toUpdate: toUpdate)
    }

    /// Server-wins: remote always overwrites local for friendships.
    static func applyFriendships(
        remote: [FriendshipRecord],
        knownFriendIDs: Set<String>
    ) -> FriendshipDiff {
        var toInsert: [FriendshipRecord] = []
        var toUpdate: [FriendshipRecord] = []

        for record in remote {
            if knownFriendIDs.contains(record.friendID) {
                toUpdate.append(record)
            } else {
                toInsert.append(record)
            }
        }

        return FriendshipDiff(toInsert: toInsert, toUpdate: toUpdate)
    }
}
