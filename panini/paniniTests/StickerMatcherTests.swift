import XCTest
@testable import panini

final class StickerMatcherTests: XCTestCase {

    func testMatch_noOverlap_returnsEmpty() {
        let result = StickerMatcher.match(
            myWishlist: ["FRA-20"],
            myAvailableDupes: ["BRA-07"],
            theirWishlist: ["GER-10"],
            theirAvailableDupes: ["ARG-10"]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMatch_mutualOverlap_returnsSuggestion() {
        let result = StickerMatcher.match(
            myWishlist: ["ARG-10"],
            myAvailableDupes: ["BRA-07"],
            theirWishlist: ["BRA-07"],
            theirAvailableDupes: ["ARG-10"]
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.give, "BRA-07")
        XCTAssertEqual(result.first?.receive, "ARG-10")
    }

    func testMatch_blacklistedDupeExcluded() {
        let result = StickerMatcher.match(
            myWishlist: ["ARG-10"],
            myAvailableDupes: [],          // BRA-07 is blacklisted, not passed in
            theirWishlist: ["BRA-07"],
            theirAvailableDupes: ["ARG-10"]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMatch_emptyMyWishlist_returnsEmpty() {
        let result = StickerMatcher.match(
            myWishlist: [],
            myAvailableDupes: ["BRA-07"],
            theirWishlist: ["BRA-07"],
            theirAvailableDupes: ["ARG-10"]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMatch_emptyTheirWishlist_returnsEmpty() {
        let result = StickerMatcher.match(
            myWishlist: ["ARG-10"],
            myAvailableDupes: ["BRA-07"],
            theirWishlist: [],
            theirAvailableDupes: ["ARG-10"]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMatch_multipleSuggestions_rankedByScore() {
        let result = StickerMatcher.match(
            myWishlist: ["ARG-10", "POR-07"],
            myAvailableDupes: ["BRA-07", "GER-13"],
            theirWishlist: ["BRA-07", "GER-13"],
            theirAvailableDupes: ["ARG-10", "POR-07"]
        )
        XCTAssertEqual(result.count, 2)
        // Scores should be non-increasing
        if result.count >= 2 {
            XCTAssertGreaterThanOrEqual(result[0].score, result[1].score)
        }
    }

    func testMatch_noDuplicateSuggestions() {
        let result = StickerMatcher.match(
            myWishlist: ["ARG-10"],
            myAvailableDupes: ["BRA-07", "BRA-07"],  // same ID twice (edge case)
            theirWishlist: ["BRA-07"],
            theirAvailableDupes: ["ARG-10"]
        )
        let ids = result.map { $0.give }
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
