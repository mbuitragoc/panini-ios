import Foundation

// MARK: - OCRParserResult

/// The result produced by the OCR parser for a single sticker recognition pass.
struct OCRParserResult {
    /// Parsed sticker ID (e.g. "FRA-20"), or nil when no match was found.
    let stickerID: String?
    /// Parser confidence in the result, in the range 0.0 – 1.0.
    let confidence: Float
}

// MARK: - OCRParser

/// Parses raw text recognised by VisionKit into structured sticker identifiers.
///
/// Both parsing methods are stubs — the full implementation is delivered in slice #5.
struct OCRParser {
    /// Parses raw recognised text from the back of a sticker.
    ///
    /// Expected pattern: `[COUNTRY_CODE]\s?\d+` — e.g. "FRA 20" or "FRA20".
    ///
    /// - Parameter text: Raw string from VisionKit recognition.
    /// - Returns: An `OCRParserResult` with the parsed sticker ID and confidence.
    static func parseBack(_ text: String) -> OCRParserResult {
        // Stub — returns a nil result until slice #5.
        return OCRParserResult(stickerID: nil, confidence: 0)
    }

    /// Parses text from the front of a sticker: player name and team.
    ///
    /// - Parameters:
    ///   - text: Raw string from VisionKit recognition.
    ///   - knownTeams: List of known national team codes used to improve matching.
    /// - Returns: An `OCRParserResult` with the parsed sticker ID and confidence.
    static func parseFront(_ text: String, knownTeams: [String]) -> OCRParserResult {
        // Stub — returns a nil result until slice #5.
        return OCRParserResult(stickerID: nil, confidence: 0)
    }
}
