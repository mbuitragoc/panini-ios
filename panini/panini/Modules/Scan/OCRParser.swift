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
struct OCRParser {

    // MARK: - Back-of-sticker parsing

    /// Parses raw recognised text from the back of a sticker.
    ///
    /// Expected pattern: `[COUNTRY_CODE]\s?-?\d+` — e.g. "FRA 20", "FRA20", "fra-20".
    /// Searches line-by-line so surrounding OCR noise is ignored.
    ///
    /// Confidence: 0.95 for 3-letter codes, 0.5 for 2-letter codes.
    static func parseBack(_ text: String) -> OCRParserResult {
        guard !text.isEmpty else { return OCRParserResult(stickerID: nil, confidence: 0) }

        let normalized = text.uppercased()
        let lines = normalized.components(separatedBy: .newlines)

        // Matches: 2–3 uppercase letters, optional whitespace/hyphen, 1–3 digits.
        let pattern = try! NSRegularExpression(pattern: #"([A-Z]{2,3})\s?-?\s?(\d{1,3})"#)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = pattern.firstMatch(in: trimmed, range: nsRange),
                  let codeRange   = Range(match.range(at: 1), in: trimmed),
                  let numberRange = Range(match.range(at: 2), in: trimmed) else { continue }

            let code   = String(trimmed[codeRange])
            let number = String(trimmed[numberRange])
            // 3-letter codes are well-formed Panini codes; 2-letter codes are ambiguous.
            let confidence: Float = code.count == 3 ? 0.95 : 0.5
            return OCRParserResult(stickerID: "\(code)-\(number)", confidence: confidence)
        }

        return OCRParserResult(stickerID: nil, confidence: 0)
    }

    // MARK: - Front-of-sticker parsing

    /// Parses text from the front of a sticker by matching a national team name
    /// against the provided list of known team codes.
    ///
    /// Returns the matched country code as the stickerID (e.g. "FRA"), which
    /// callers use to narrow the sticker list for the user to confirm.
    ///
    /// - Parameters:
    ///   - text: Raw string from VisionKit recognition.
    ///   - knownTeams: Country codes present in the local sticker database.
    static func parseFront(_ text: String, knownTeams: [String]) -> OCRParserResult {
        guard !text.isEmpty else { return OCRParserResult(stickerID: nil, confidence: 0) }

        let lowered = text.lowercased()
        let knownSet = Set(knownTeams)

        for (name, code) in Self.countryNameToCode {
            guard lowered.contains(name), knownSet.contains(code) else { continue }
            return OCRParserResult(stickerID: code, confidence: 0.75)
        }

        return OCRParserResult(stickerID: nil, confidence: 0)
    }

    // MARK: - Country name → code lookup

    private static let countryNameToCode: [String: String] = [
        "france":          "FRA",
        "spain":           "ESP",
        "colombia":        "COL",
        "brazil":          "BRA",
        "germany":         "GER",
        "argentina":       "ARG",
        "portugal":        "POR",
        "england":         "ENG",
        "united states":   "USA",
        "mexico":          "MEX",
        "netherlands":     "NED",
        "italy":           "ITA",
        "croatia":         "CRO",
        "morocco":         "MAR",
        "japan":           "JPN",
        "south korea":     "KOR",
        "australia":       "AUS",
        "switzerland":     "SUI",
        "ecuador":         "ECU",
        "uruguay":         "URU",
        "ghana":           "GHA",
        "cameroon":        "CMR",
        "senegal":         "SEN",
        "canada":          "CAN",
        "qatar":           "QAT",
        "poland":          "POL",
        "denmark":         "DEN",
        "belgium":         "BEL",
        "wales":           "WAL",
        "serbia":          "SRB",
        "saudi arabia":    "SAU",
        "costa rica":      "CRC",
        "paraguay":        "PAR",
        "peru":            "PER",
        "nigeria":         "NGA",
        "egypt":           "EGY",
        "tunisia":         "TUN",
        "iran":            "IRN",
    ]
}
