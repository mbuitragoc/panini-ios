import XCTest
@testable import panini

final class OCRParserTests: XCTestCase {

    // MARK: Back-of-sticker ID parsing

    func testParseBack_standardFormat() {
        let result = OCRParser.parseBack("FRA 20")
        XCTAssertEqual(result.stickerID, "FRA-20")
        XCTAssertGreaterThan(result.confidence, 0.8)
    }

    func testParseBack_noSpace() {
        let result = OCRParser.parseBack("FRA20")
        XCTAssertEqual(result.stickerID, "FRA-20")
    }

    func testParseBack_hyphenated() {
        let result = OCRParser.parseBack("FRA-20")
        XCTAssertEqual(result.stickerID, "FRA-20")
    }

    func testParseBack_lowercase() {
        let result = OCRParser.parseBack("fra 20")
        XCTAssertEqual(result.stickerID, "FRA-20")
    }

    func testParseBack_mixedCase() {
        let result = OCRParser.parseBack("Fra 20")
        XCTAssertEqual(result.stickerID, "FRA-20")
    }

    func testParseBack_singleDigit() {
        let result = OCRParser.parseBack("BRA 7")
        XCTAssertEqual(result.stickerID, "BRA-7")
    }

    func testParseBack_threeDigit() {
        let result = OCRParser.parseBack("GER 100")
        XCTAssertEqual(result.stickerID, "GER-100")
    }

    func testParseBack_withSurroundingNoise() {
        let result = OCRParser.parseBack("Album\nFRA 20\nPanini")
        XCTAssertEqual(result.stickerID, "FRA-20")
    }

    func testParseBack_unrecognisable_returnsNil() {
        let result = OCRParser.parseBack("Hello World")
        XCTAssertNil(result.stickerID)
        XCTAssertEqual(result.confidence, 0)
    }

    func testParseBack_emptyString_returnsNil() {
        let result = OCRParser.parseBack("")
        XCTAssertNil(result.stickerID)
    }

    func testParseBack_partialRead_lowConfidence() {
        let result = OCRParser.parseBack("FR 20")
        // Too short a code — either nil or low confidence
        if result.stickerID != nil {
            XCTAssertLessThan(result.confidence, 0.7)
        }
    }

    // MARK: Front-of-sticker parsing

    func testParseFront_matchesKnownTeam() {
        let result = OCRParser.parseFront("Kylian Mbappé\nFrance\nFWD", knownTeams: ["FRA", "BRA", "GER"])
        XCTAssertNotNil(result.stickerID)
    }

    func testParseFront_unknownTeam_returnsNil() {
        let result = OCRParser.parseFront("Some Player\nUnknownNation\nMID", knownTeams: ["FRA", "BRA"])
        XCTAssertNil(result.stickerID)
    }

    func testParseFront_emptyText_returnsNil() {
        let result = OCRParser.parseFront("", knownTeams: ["FRA"])
        XCTAssertNil(result.stickerID)
    }
}
