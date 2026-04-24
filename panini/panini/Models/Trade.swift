import Foundation
import SwiftData

@Model
final class Trade {
    @Attribute(.unique) var id: String
    var proposerID: String
    var recipientID: String
    var status: String
    var offeredStickers: [String]
    var requestedStickers: [String]
    var proposedAt: Date
    var resolvedAt: Date?
    var completedAt: Date?
    var updatedAt: Date

    init(
        id: String,
        proposerID: String,
        recipientID: String,
        status: String = "proposed",
        offeredStickers: [String] = [],
        requestedStickers: [String] = [],
        proposedAt: Date = .now,
        resolvedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.proposerID = proposerID
        self.recipientID = recipientID
        self.status = status
        self.offeredStickers = offeredStickers
        self.requestedStickers = requestedStickers
        self.proposedAt = proposedAt
        self.resolvedAt = resolvedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}
