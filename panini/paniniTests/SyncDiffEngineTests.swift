import XCTest
@testable import panini

final class SyncDiffEngineTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private let t1 = Date(timeIntervalSinceReferenceDate: 100)

    // MARK: - Collections (LWW by updatedAt)

    func test_collection_emptyRemote_producesNoDiff() {
        let diff = SyncDiffEngine.applyCollections(
            remote: [],
            localUpdatedAts: ["ESP-3": t0, "FRA-15": t1]
        )

        XCTAssertTrue(diff.toInsert.isEmpty)
        XCTAssertTrue(diff.toUpdate.isEmpty)
    }

    func test_collection_remoteOlder_keepsLocal() {
        let remote = [SyncDiffEngine.CollectionRecord(
            stickerID: "ESP-3",
            quantityOwned: 5,
            wishlisted: false,
            blacklisted: false,
            firstAcquiredAt: t0,
            updatedAt: t0          // older than local
        )]

        let diff = SyncDiffEngine.applyCollections(
            remote: remote,
            localUpdatedAts: ["ESP-3": t1]  // local is newer
        )

        XCTAssertTrue(diff.toUpdate.isEmpty)
        XCTAssertTrue(diff.toInsert.isEmpty)
    }

    func test_collection_noLocalMatch_insertsNew() {
        let remote = [SyncDiffEngine.CollectionRecord(
            stickerID: "FRA-15",
            quantityOwned: 1,
            wishlisted: false,
            blacklisted: false,
            firstAcquiredAt: t0,
            updatedAt: t1
        )]

        let diff = SyncDiffEngine.applyCollections(
            remote: remote,
            localUpdatedAts: [:]    // no local records
        )

        XCTAssertEqual(diff.toInsert.count, 1)
        XCTAssertEqual(diff.toInsert.first?.stickerID, "FRA-15")
        XCTAssertTrue(diff.toUpdate.isEmpty)
    }

    func test_collection_remoteNewer_updatesLocal() {
        let remote = [SyncDiffEngine.CollectionRecord(
            stickerID: "ESP-3",
            quantityOwned: 2,
            wishlisted: false,
            blacklisted: false,
            firstAcquiredAt: t0,
            updatedAt: t1
        )]

        let diff = SyncDiffEngine.applyCollections(
            remote: remote,
            localUpdatedAts: ["ESP-3": t0]
        )

        XCTAssertEqual(diff.toUpdate.count, 1)
        XCTAssertEqual(diff.toUpdate.first?.stickerID, "ESP-3")
        XCTAssertEqual(diff.toUpdate.first?.quantityOwned, 2)
        XCTAssertTrue(diff.toInsert.isEmpty)
    }

    // MARK: - Trades (server-wins)

    func test_trade_serverWins_updatesEvenWhenRemoteOlder() {
        let remote = [SyncDiffEngine.TradeRecord(
            id: "trade-1",
            proposerID: "user-A",
            recipientID: "user-B",
            status: "accepted",
            offeredStickers: ["ESP-3"],
            requestedStickers: ["FRA-15"],
            proposedAt: t0,
            resolvedAt: t1,
            completedAt: nil,
            updatedAt: t0   // older than local — but server still wins
        )]

        let diff = SyncDiffEngine.applyTrades(
            remote: remote,
            knownIDs: ["trade-1"]
        )

        XCTAssertEqual(diff.toUpdate.count, 1)
        XCTAssertEqual(diff.toUpdate.first?.status, "accepted")
        XCTAssertTrue(diff.toInsert.isEmpty)
    }

    func test_trade_noLocalMatch_insertsNew() {
        let remote = [SyncDiffEngine.TradeRecord(
            id: "trade-99",
            proposerID: "user-A",
            recipientID: "user-B",
            status: "proposed",
            offeredStickers: ["COL-16"],
            requestedStickers: ["ESP-16"],
            proposedAt: t0,
            resolvedAt: nil,
            completedAt: nil,
            updatedAt: t0
        )]

        let diff = SyncDiffEngine.applyTrades(
            remote: remote,
            knownIDs: []
        )

        XCTAssertEqual(diff.toInsert.count, 1)
        XCTAssertEqual(diff.toInsert.first?.id, "trade-99")
        XCTAssertTrue(diff.toUpdate.isEmpty)
    }

    // MARK: - Friendships (server-wins)

    func test_friendship_updatesExistingStatusAndProfile() {
        let remote = [SyncDiffEngine.FriendshipRecord(
            friendID: "friend-1",
            friendUsername: "Alice Updated",
            friendHandle: "alice_new",
            friendOwnedCount: 42,
            status: "accepted",
            updatedAt: t1
        )]

        let diff = SyncDiffEngine.applyFriendships(
            remote: remote,
            knownFriendIDs: ["friend-1"]
        )

        XCTAssertEqual(diff.toUpdate.count, 1)
        XCTAssertEqual(diff.toUpdate.first?.friendHandle, "alice_new")
        XCTAssertEqual(diff.toUpdate.first?.friendOwnedCount, 42)
        XCTAssertEqual(diff.toUpdate.first?.status, "accepted")
        XCTAssertTrue(diff.toInsert.isEmpty)
    }

    func test_friendship_noLocalMatch_insertsNew() {
        let remote = [SyncDiffEngine.FriendshipRecord(
            friendID: "friend-99",
            friendUsername: "Bob",
            friendHandle: "bob_handle",
            friendOwnedCount: 7,
            status: "pending",
            updatedAt: t0
        )]

        let diff = SyncDiffEngine.applyFriendships(
            remote: remote,
            knownFriendIDs: []
        )

        XCTAssertEqual(diff.toInsert.count, 1)
        XCTAssertEqual(diff.toInsert.first?.friendID, "friend-99")
        XCTAssertTrue(diff.toUpdate.isEmpty)
    }
}
