import Foundation
import SwiftData

@Model
final class UserCollection {
    var userID: String
    var stickerID: String
    var quantityOwned: Int
    var wishlisted: Bool
    var blacklisted: Bool
    var firstAcquiredAt: Date?
    var updatedAt: Date

    init(
        userID: String,
        stickerID: String,
        quantityOwned: Int = 0,
        wishlisted: Bool = false,
        blacklisted: Bool = false,
        firstAcquiredAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.userID = userID
        self.stickerID = stickerID
        self.quantityOwned = quantityOwned
        self.wishlisted = wishlisted
        self.blacklisted = blacklisted
        self.firstAcquiredAt = firstAcquiredAt
        self.updatedAt = updatedAt
    }
}
