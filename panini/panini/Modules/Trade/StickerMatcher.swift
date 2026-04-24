import Foundation

// MARK: - SuggestedTrade

/// A suggested sticker trade between two collectors.
struct SuggestedTrade {
    /// Sticker ID that the initiating user gives away.
    let give: String
    /// Sticker ID that the initiating user receives.
    let receive: String
    /// Match quality score — higher values indicate better mutual wishlist value.
    let score: Int
}

// MARK: - StickerMatcher

/// Pure stateless matching engine — no network or persistence dependencies.
struct StickerMatcher {
    /// Returns suggested trades ranked by mutual wishlist value.
    ///
    /// Each sticker ID appears at most once across all returned suggestions (1:1 matching).
    /// Callers are responsible for filtering out blacklisted dupes before passing them in.
    static func match(
        myWishlist: [String],
        myAvailableDupes: [String],
        theirWishlist: [String],
        theirAvailableDupes: [String]
    ) -> [SuggestedTrade] {
        // Stickers I can give that my friend actually wants
        let givePool = Set(myAvailableDupes).intersection(Set(theirWishlist))
        // Stickers my friend can give that I actually want
        let receivePool = Set(theirAvailableDupes).intersection(Set(myWishlist))

        guard !givePool.isEmpty && !receivePool.isEmpty else { return [] }

        // Sort for deterministic output
        let sortedGive = givePool.sorted()
        let sortedReceive = receivePool.sorted()

        // Greedy 1:1 assignment — each sticker appears in at most one suggestion
        var usedReceive = Set<String>()
        var results: [SuggestedTrade] = []

        for give in sortedGive {
            guard let receive = sortedReceive.first(where: { !usedReceive.contains($0) }) else { break }
            usedReceive.insert(receive)
            results.append(SuggestedTrade(give: give, receive: receive, score: 2))
        }

        return results
    }
}
