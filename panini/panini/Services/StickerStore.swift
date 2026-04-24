import Foundation
import SQLite3
import SwiftData
import Observation

// MARK: - StickerStore

/// Reads the bundled stickers.sqlite checklist and seeds SwiftData on first launch.
/// All downstream features query SwiftData directly — this runs once and is a no-op thereafter.
@Observable
final class StickerStore {
    private(set) var isSeeded = false

    /// Seeds SwiftData from the bundled SQLite file if the stickers table is empty.
    /// Safe to call on every launch — exits immediately if data is already present.
    @MainActor
    func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Sticker>())) ?? 0
        guard existing == 0 else {
            isSeeded = true
            return
        }

        guard let rows = readBundledSQLite() else { return }

        for row in rows {
            context.insert(Sticker(
                id: row.id,
                countryCode: row.countryCode,
                stickerNumber: row.stickerNumber,
                type: row.type,
                playerName: row.playerName,
                nationalTeam: row.nationalTeam,
                club: row.club,
                clubCountry: row.clubCountry,
                position: row.position
            ))
        }
        try? context.save()
        isSeeded = true
    }

    // MARK: - Private

    private struct Row {
        let id, countryCode: String
        let stickerNumber: Int
        let type: String
        let playerName, position, nationalTeam, club, clubCountry: String?
    }

    private func readBundledSQLite() -> [Row]? {
        guard let url = Bundle.main.url(forResource: "stickers", withExtension: "sqlite") else {
            return nil
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT id, country_code, sticker_number, type,
                   player_name, position, national_team, club, club_country
            FROM stickers
            ORDER BY country_code, sticker_number
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        var rows: [Row] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(Row(
                id:            col(stmt, 0) ?? "",
                countryCode:   col(stmt, 1) ?? "",
                stickerNumber: Int(sqlite3_column_int(stmt, 2)),
                type:          col(stmt, 3) ?? "player",
                playerName:    col(stmt, 4),
                position:      col(stmt, 5),
                nationalTeam:  col(stmt, 6) ?? "",
                club:          col(stmt, 7),
                clubCountry:   col(stmt, 8)
            ))
        }
        return rows
    }

    private func col(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: ptr)
    }
}
