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

    func testParseBack_worldCupLogoNoise_picksCorrectCode() {
        // "FIFA WORLD CUP 2026" yields "CUP-202" without an allowlist; with one it must skip to FRA-20.
        let result = OCRParser.parseBack(
            "FIFA WORLD CUP 2026\nFRA 20",
            knownTeams: ["FRA", "BRA", "GER", "ARG"]
        )
        XCTAssertEqual(result.stickerID, "FRA-20")
    }

    func testParseBack_worldCupSingleLine_picksCorrectCode() {
        let result = OCRParser.parseBack(
            "FIFA WORLD CUP 2026 FRA 20",
            knownTeams: ["FRA", "BRA", "GER"]
        )
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

    func testParseBack_cleanItem_matchesEvenWhenNotInKnownTeams() {
        // "ARG 14" is the entire VisionKit item — bypass the allowlist and still match.
        let result = OCRParser.parseBack("ARG 14", knownTeams: ["FRA", "BRA"])
        XCTAssertEqual(result.stickerID, "ARG-14")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)
    }

    func testParseBack_noiseItem_blockedByAllowlist() {
        // "FIFA WORLD CUP 2026" embeds "CUP 202" as a partial match — allowlist must block it.
        let result = OCRParser.parseBack("FIFA WORLD CUP 2026", knownTeams: ["FRA", "ARG"])
        XCTAssertNil(result.stickerID)
    }

    func testParseBack_splitAcrossItems_matchesViaFullText() {
        // VisionKit sometimes returns code and number as separate text items.
        // The coordinator joins them with "\n"; Phase 2 must catch this.
        let result = OCRParser.parseBack("ARG\n14", knownTeams: ["ARG", "FRA", "BRA"])
        XCTAssertEqual(result.stickerID, "ARG-14")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
    }

    func testParseBack_splitSingleDigit_matchesViaFullText() {
        let result = OCRParser.parseBack("ARG\n5", knownTeams: ["ARG", "FRA"])
        XCTAssertEqual(result.stickerID, "ARG-5")
    }

    // MARK: Front-of-sticker parsing

    func testParseFront_matchesKnownTeam() {
        let result = OCRParser.parseFront("Kylian Mbappé\nFrance\nFWD", knownTeams: ["FRA", "BRA", "GER"])
        XCTAssertNotNil(result.stickerID)
    }

    func testParseFront_matchesCodeAbbreviation() {
        // Sticker front shows "ARG" — no full country name, code fallback must fire.
        let result = OCRParser.parseFront("Lionel Messi\nARG\nFWD", knownTeams: ["ARG", "FRA", "BRA"])
        XCTAssertEqual(result.stickerID, "ARG")
        XCTAssertGreaterThan(result.confidence, 0)
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
