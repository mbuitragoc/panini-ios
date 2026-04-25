import Foundation
import SwiftData

@Model
final class Sticker {
    @Attribute(.unique) var id: String
    var countryCode: String
    var stickerNumber: Int
    var type: String
    var playerName: String?
    var dob: Date?
    var height: Double?
    var weight: Double?
    var club: String?
    var clubCountry: String?
    var position: String?
    var nationalTeam: String
    var imageURL: String?
    var rarity: String

    @Relationship(deleteRule: .cascade) var collection: UserCollection?
    @Relationship(deleteRule: .nullify, inverse: \PlayerRating.sticker) var rating: PlayerRating?

    init(
        id: String,
        countryCode: String,
        stickerNumber: Int,
        type: String,
        playerName: String? = nil,
        dob: Date? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        club: String? = nil,
        clubCountry: String? = nil,
        position: String? = nil,
        nationalTeam: String,
        imageURL: String? = nil,
        rarity: String = "base"
    ) {
        self.id = id
        self.countryCode = countryCode
        self.stickerNumber = stickerNumber
        self.type = type
        self.playerName = playerName
        self.dob = dob
        self.height = height
        self.weight = weight
        self.club = club
        self.clubCountry = clubCountry
        self.position = position
        self.nationalTeam = nationalTeam
        self.imageURL = imageURL
        self.rarity = rarity
    }
}
