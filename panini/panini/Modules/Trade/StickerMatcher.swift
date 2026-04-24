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
///
/// The full scoring algorithm is delivered in slice #14.
struct StickerMatcher {
    /// Returns suggested trades ranked by mutual wishlist value.
    ///
    /// - Parameters:
    ///   - myWishlist: Sticker IDs the initiating user wants.
    ///   - myAvailableDupes: Sticker IDs the initiating user can offer (non-blacklisted dupes).
    ///   - theirWishlist: Sticker IDs the counterparty wants.
    ///   - theirAvailableDupes: Sticker IDs the counterparty can offer (non-blacklisted dupes).
    /// - Returns: Ranked array of `SuggestedTrade` values, best match first.
    static func match(
        myWishlist: [String],
        myAvailableDupes: [String],
        theirWishlist: [String],
        theirAvailableDupes: [String]
    ) -> [SuggestedTrade] {
        // Stub — returns empty array until slice #14.
        return []
    }
}
