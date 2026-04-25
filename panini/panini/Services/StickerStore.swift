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

    /// Merges duplicate UserCollection records that share the same stickerID.
    /// Caused by a bug where sticker.collection was never wired after insert,
    /// leaving sticker.collection = nil so every scan created a new record.
    /// Safe to call every launch — scans once and exits immediately if data is clean.
    @MainActor
    func repairDuplicateCollections(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<UserCollection>()) else { return }

        let grouped = Dictionary(grouping: all, by: \.stickerID)
        var dirty = false

        for (stickerID, records) in grouped {
            // Also delete orphaned records where quantityOwned == 0 with no sticker match.
            if records.count == 1 {
                // Re-wire the relationship in case it was never set.
                let sid = stickerID
                if let sticker = try? context.fetch(
                    FetchDescriptor<Sticker>(predicate: #Predicate { $0.id == sid })
                ).first, sticker.collection == nil {
                    sticker.collection = records[0]
                    dirty = true
                }
                continue
            }

            // Multiple records for the same stickerID: merge into one.
            let sorted = records.sorted { ($0.updatedAt) > ($1.updatedAt) }
            let keeper = sorted[0]
            keeper.quantityOwned   = records.reduce(0) { $0 + $1.quantityOwned }
            keeper.firstAcquiredAt = records.compactMap(\.firstAcquiredAt).min() ?? keeper.firstAcquiredAt
            keeper.updatedAt       = .now

            for dupe in sorted.dropFirst() { context.delete(dupe) }

            let sid = stickerID
            if let sticker = try? context.fetch(
                FetchDescriptor<Sticker>(predicate: #Predicate { $0.id == sid })
            ).first {
                sticker.collection = keeper
            }
            dirty = true
        }

        if dirty { try? context.save() }
    }

    /// Seeds SwiftData from the bundled SQLite.
    /// On first launch inserts everything. On subsequent launches runs an incremental
    /// merge so catalog updates (new stickers, filled-in player names) are picked up
    /// without wiping user collection data.
    @MainActor
    func seedIfNeeded(context: ModelContext) {
        guard let rows = readBundledSQLite(), !rows.isEmpty else {
            isSeeded = true
            return
        }

        let existingCount = (try? context.fetchCount(FetchDescriptor<Sticker>())) ?? 0

        if existingCount == 0 {
            // Fresh install — insert everything in one pass.
            for row in rows { context.insert(makeSticker(from: row)) }
            try? context.save()
        } else if existingCount != rows.count {
            // Catalog changed (new stickers added or removed from the bundle).
            // Insert missing entries; update placeholders that now have a player name.
            let existing = (try? context.fetch(FetchDescriptor<Sticker>())) ?? []
            let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            var dirty = false

            for row in rows {
                if let sticker = byID[row.id] {
                    // Fill in player name if it was a placeholder and the catalog now has one.
                    if sticker.playerName == nil, let name = row.playerName {
                        sticker.playerName = name
                        sticker.position   = row.position
                        sticker.club       = row.club
                        sticker.clubCountry = row.clubCountry
                        dirty = true
                    }
                } else {
                    context.insert(makeSticker(from: row))
                    dirty = true
                }
            }
            if dirty { try? context.save() }
        }

        isSeeded = true
        seedRatingsIfNeeded(context: context)
    }

    private func makeSticker(from row: Row) -> Sticker {
        Sticker(
            id: row.id,
            countryCode: row.countryCode,
            stickerNumber: row.stickerNumber,
            type: row.type,
            playerName: row.playerName,
            club: row.club,
            clubCountry: row.clubCountry,
            position: row.position,
            nationalTeam: row.nationalTeam
        )
    }

    /// Seeds PlayerRating records from the bundled SQLite if none exist yet.
    /// Also called from seedIfNeeded (after stickers) and from the app launch task
    /// to handle the case where the app was updated and stickers already exist.
    @MainActor
    func seedRatingsIfNeeded(context: ModelContext) {
        let existingStickers = (try? context.fetchCount(FetchDescriptor<Sticker>())) ?? 0
        let existingRatings = (try? context.fetchCount(FetchDescriptor<PlayerRating>())) ?? 0
        guard existingStickers > 0, existingRatings == 0 else { return }

        guard let ratingRows = readBundledRatings() else { return }

        for row in ratingRows {
            let sid = row.stickerID
            guard let sticker = try? context.fetch(
                FetchDescriptor<Sticker>(predicate: #Predicate { $0.id == sid })
            ).first else { continue }

            let rating = PlayerRating(
                stickerID: row.stickerID,
                overall: row.overall,
                pace: row.pace,
                shooting: row.shooting,
                passing: row.passing,
                dribbling: row.dribbling,
                defending: row.defending,
                physical: row.physical,
                gkDiving: row.gkDiving,
                gkHandling: row.gkHandling,
                gkKicking: row.gkKicking,
                gkReflexes: row.gkReflexes,
                gkSpeed: row.gkSpeed,
                gkPositioning: row.gkPositioning,
                nationPosition: row.nationPosition,
                nationJerseyNumber: row.nationJerseyNumber,
                playStyles: row.playStyles,
                rarity: row.rarity,
                confidence: row.confidence
            )
            context.insert(rating)
            rating.sticker = sticker
            sticker.rating = rating
        }
        try? context.save()
    }

    // MARK: - Private

    private struct Row {
        let id, countryCode, type, nationalTeam: String
        let stickerNumber: Int
        let playerName, position, club, clubCountry: String?
    }

    private struct RatingRow {
        let stickerID: String
        let overall, pace, shooting, passing, dribbling, defending, physical: Int
        let gkDiving, gkHandling, gkKicking, gkReflexes, gkSpeed, gkPositioning: Int
        let nationPosition: String?
        let nationJerseyNumber: Int?
        let playStyles: [String]
        let rarity, confidence: String
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
                type:          col(stmt, 3) ?? "player",
                nationalTeam:  col(stmt, 6) ?? "",
                stickerNumber: Int(sqlite3_column_int(stmt, 2)),
                playerName:    col(stmt, 4),
                position:      col(stmt, 5),
                club:          col(stmt, 7),
                clubCountry:   col(stmt, 8)
            ))
        }
        return rows
    }

    private func readBundledRatings() -> [RatingRow]? {
        guard let url = Bundle.main.url(forResource: "stickers", withExtension: "sqlite") else {
            return nil
        }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db); return nil
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT spl.sticker_id,
                   pr.overall, pr.pace, pr.shooting, pr.passing,
                   pr.dribbling, pr.defending, pr.physical,
                   pr.gk_diving, pr.gk_handling, pr.gk_kicking,
                   pr.gk_reflexes, pr.gk_speed, pr.gk_positioning,
                   pr.nation_position, pr.nation_jersey_number,
                   pr.play_styles, pr.rarity, spl.confidence
            FROM sticker_player_link spl
            JOIN player_ratings pr ON pr.id = spl.player_rating_id
            WHERE spl.player_rating_id IS NOT NULL
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        var rows: [RatingRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let jerseyRaw = Int(sqlite3_column_int(stmt, 15))
            let playStylesJSON = col(stmt, 16) ?? "[]"
            let playStyles = (try? JSONDecoder().decode([String].self,
                from: Data(playStylesJSON.utf8))) ?? []

            rows.append(RatingRow(
                stickerID:       col(stmt, 0) ?? "",
                overall:         Int(sqlite3_column_int(stmt, 1)),
                pace:            Int(sqlite3_column_int(stmt, 2)),
                shooting:        Int(sqlite3_column_int(stmt, 3)),
                passing:         Int(sqlite3_column_int(stmt, 4)),
                dribbling:       Int(sqlite3_column_int(stmt, 5)),
                defending:       Int(sqlite3_column_int(stmt, 6)),
                physical:        Int(sqlite3_column_int(stmt, 7)),
                gkDiving:        Int(sqlite3_column_int(stmt, 8)),
                gkHandling:      Int(sqlite3_column_int(stmt, 9)),
                gkKicking:       Int(sqlite3_column_int(stmt, 10)),
                gkReflexes:      Int(sqlite3_column_int(stmt, 11)),
                gkSpeed:         Int(sqlite3_column_int(stmt, 12)),
                gkPositioning:   Int(sqlite3_column_int(stmt, 13)),
                nationPosition:  col(stmt, 14),
                nationJerseyNumber: jerseyRaw == 0 ? nil : jerseyRaw,
                playStyles:      playStyles,
                rarity:          col(stmt, 17) ?? "bronze",
                confidence:      col(stmt, 18) ?? "unmatched"
            ))
        }
        return rows
    }

    private func col(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: ptr)
    }
}
