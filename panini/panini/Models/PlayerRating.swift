import Foundation
import SwiftData

@Model
final class PlayerRating {
    @Attribute(.unique) var stickerID: String

    var overall: Int
    var pace: Int
    var shooting: Int
    var passing: Int
    var dribbling: Int
    var defending: Int
    var physical: Int
    var gkDiving: Int
    var gkHandling: Int
    var gkKicking: Int
    var gkReflexes: Int
    var gkSpeed: Int
    var gkPositioning: Int
    var nationPosition: String?
    var nationJerseyNumber: Int?
    var playStyles: [String]
    var rarity: String
    var confidence: String

    var sticker: Sticker?

    var isGK: Bool {
        nationPosition == "GK" || (pace == 0 && shooting == 0 && passing == 0)
    }

    init(
        stickerID: String,
        overall: Int,
        pace: Int = 0,
        shooting: Int = 0,
        passing: Int = 0,
        dribbling: Int = 0,
        defending: Int = 0,
        physical: Int = 0,
        gkDiving: Int = 0,
        gkHandling: Int = 0,
        gkKicking: Int = 0,
        gkReflexes: Int = 0,
        gkSpeed: Int = 0,
        gkPositioning: Int = 0,
        nationPosition: String? = nil,
        nationJerseyNumber: Int? = nil,
        playStyles: [String] = [],
        rarity: String = "bronze",
        confidence: String = "unmatched"
    ) {
        self.stickerID = stickerID
        self.overall = overall
        self.pace = pace
        self.shooting = shooting
        self.passing = passing
        self.dribbling = dribbling
        self.defending = defending
        self.physical = physical
        self.gkDiving = gkDiving
        self.gkHandling = gkHandling
        self.gkKicking = gkKicking
        self.gkReflexes = gkReflexes
        self.gkSpeed = gkSpeed
        self.gkPositioning = gkPositioning
        self.nationPosition = nationPosition
        self.nationJerseyNumber = nationJerseyNumber
        self.playStyles = playStyles
        self.rarity = rarity
        self.confidence = confidence
    }
}
