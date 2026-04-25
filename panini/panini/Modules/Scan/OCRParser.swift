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
    /// Iterates every match on every line so "CUP 202" in "FIFA WORLD CUP 2026" is
    /// skipped when an allowlist of valid codes is provided.
    ///
    /// - Parameter knownTeams: When non-empty, only matches whose country code is in
    ///   this set are accepted. Pass the codes from the local sticker database.
    /// Confidence: 0.95 for 3-letter codes, 0.5 for 2-letter codes.
    static func parseBack(_ text: String, knownTeams: Set<String> = []) -> OCRParserResult {
        guard !text.isEmpty else { return OCRParserResult(stickerID: nil, confidence: 0) }

        let normalized = text.uppercased()
        let lines = normalized.components(separatedBy: .newlines)

        // Matches: 2–3 uppercase letters, optional whitespace/hyphen, 1–3 digits.
        let pattern = try! NSRegularExpression(pattern: #"([A-Z]{2,3})\s?-?\s?(\d{1,3})"#)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = pattern.matches(in: trimmed, range: nsRange)

            for match in matches {
                guard let codeRange   = Range(match.range(at: 1), in: trimmed),
                      let numberRange = Range(match.range(at: 2), in: trimmed) else { continue }

                let code   = String(trimmed[codeRange])
                let number = String(trimmed[numberRange])

                // Bypass the allowlist when the match covers the entire line — the item IS
                // the sticker code (e.g. "ARG 14"), not a false hit inside longer text (e.g.
                // "CUP 202" inside "FIFA WORLD CUP 2026" where the line has other content).
                let isFullLine = match.range.length >= trimmed.utf16.count - 1
                if !isFullLine && !knownTeams.isEmpty && !knownTeams.contains(code) { continue }

                let confidence: Float = code.count == 3 ? 0.95 : 0.5
                return OCRParserResult(stickerID: "\(code)-\(number)", confidence: confidence)
            }
        }

        // Phase 2: full-text search catches codes split across separate OCR items (e.g. "ARG\n14").
        let fullRange = NSRange(normalized.startIndex..., in: normalized)
        let fullMatches = pattern.matches(in: normalized, range: fullRange)
        for match in fullMatches {
            guard let codeRange   = Range(match.range(at: 1), in: normalized),
                  let numberRange = Range(match.range(at: 2), in: normalized) else { continue }
            let code   = String(normalized[codeRange])
            let number = String(normalized[numberRange])
            if !knownTeams.isEmpty && !knownTeams.contains(code) { continue }
            let confidence: Float = code.count == 3 ? 0.85 : 0.4
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
        let uppercased = text.uppercased()
        let knownSet = Set(knownTeams)

        // Primary: match full country name (e.g. "france" → "FRA").
        for (name, code) in Self.countryNameToCode {
            guard lowered.contains(name), knownSet.contains(code) else { continue }
            return OCRParserResult(stickerID: code, confidence: 0.75)
        }

        // Fallback: match country code abbreviation as a whole word in the text.
        // Stickers sometimes display the code directly (e.g. "ARG", "BRA").
        let wordPattern = try! NSRegularExpression(pattern: #"\b([A-Z]{3})\b"#)
        let nsRange = NSRange(uppercased.startIndex..., in: uppercased)
        let wordMatches = wordPattern.matches(in: uppercased, range: nsRange)
        for match in wordMatches {
            guard let r = Range(match.range(at: 1), in: uppercased) else { continue }
            let code = String(uppercased[r])
            if knownSet.contains(code) {
                return OCRParserResult(stickerID: code, confidence: 0.75)
            }
        }

        return OCRParserResult(stickerID: nil, confidence: 0)
    }

    // MARK: - Country name → code lookup

    private static let countryNameToCode: [String: String] = [
        // CONMEBOL
        "argentina":                    "ARG",
        "brazil":                       "BRA",
        "colombia":                     "COL",
        "ecuador":                      "ECU",
        "paraguay":                     "PAR",
        "uruguay":                      "URU",
        // UEFA
        "austria":                      "AUT",
        "belgium":                      "BEL",
        "bosnia and herzegovina":       "BIH",
        "bosnia & herzegovina":         "BIH",
        "croatia":                      "CRO",
        "czech republic":               "CZE",
        "czechia":                      "CZE",
        "england":                      "ENG",
        "france":                       "FRA",
        "germany":                      "GER",
        "netherlands":                  "NED",
        "norway":                       "NOR",
        "portugal":                     "POR",
        "scotland":                     "SCO",
        "spain":                        "ESP",
        "sweden":                       "SWE",
        "switzerland":                  "SUI",
        "turkey":                       "TUR",
        "türkiye":                      "TUR",
        // CONCACAF
        "canada":                       "CAN",
        "curaçao":                      "CUW",
        "curacao":                      "CUW",
        "haiti":                        "HAI",
        "mexico":                       "MEX",
        "panama":                       "PAN",
        "united states":                "USA",
        // AFC
        "australia":                    "AUS",
        "iran":                         "IRN",
        "iraq":                         "IRQ",
        "japan":                        "JPN",
        "jordan":                       "JOR",
        "qatar":                        "QAT",
        "saudi arabia":                 "KSA",
        "south korea":                  "KOR",
        "uzbekistan":                   "UZB",
        // CAF
        "algeria":                      "ALG",
        "cape verde":                   "CPV",
        "dr congo":                     "COD",
        "democratic republic of congo": "COD",
        "egypt":                        "EGY",
        "ghana":                        "GHA",
        "ivory coast":                  "CIV",
        "côte d'ivoire":                "CIV",
        "cote d'ivoire":                "CIV",
        "morocco":                      "MAR",
        "senegal":                      "SEN",
        "south africa":                 "RSA",
        "tunisia":                      "TUN",
        // OFC
        "new zealand":                  "NZL",
        // FWC special section
        "fifa world cup":               "FWC",
        "world cup":                    "FWC",
    ]
}
