import Foundation
import SwiftData

@Model
final class Friendship {
    var userID: String
    var friendID: String
    var friendUsername: String
    var friendHandle: String
    var friendOwnedCount: Int
    var status: String
    var sentByMe: Bool
    var updatedAt: Date

    init(
        userID: String,
        friendID: String,
        friendUsername: String,
        friendHandle: String,
        friendOwnedCount: Int = 0,
        status: String = "pending",
        sentByMe: Bool = true,
        updatedAt: Date = .now
    ) {
        self.userID = userID
        self.friendID = friendID
        self.friendUsername = friendUsername
        self.friendHandle = friendHandle
        self.friendOwnedCount = friendOwnedCount
        self.status = status
        self.sentByMe = sentByMe
        self.updatedAt = updatedAt
    }
}
