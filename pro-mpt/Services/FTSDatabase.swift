import Foundation
import SQLite3

// MARK: - SQLite FTS5 全文検索データベース

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class FTSDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "net.techgamelife.pro-mpt.fts", qos: .userInitiated)

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("pro-mpt", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        dbPath = appDir.appendingPathComponent("search_index.sqlite3").path

        openDatabase()
        createTables()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - データベース初期化

    private func openDatabase() {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            print("[FTSDatabase] データベースのオープンに失敗: \(errorMessage)")
            return
        }
        execute("PRAGMA journal_mode=WAL")
        execute("PRAGMA synchronous=NORMAL")
    }

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS prompts (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                last_used_at REAL NOT NULL,
                use_count INTEGER NOT NULL DEFAULT 1,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                character_count INTEGER NOT NULL DEFAULT 0
            )
        """)

        execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS prompts_fts USING fts5(
                content,
                title,
                content='prompts',
                content_rowid='rowid',
                tokenize='unicode61 remove_diacritics 2'
            )
        """)

        execute("""
            CREATE TRIGGER IF NOT EXISTS prompts_ai AFTER INSERT ON prompts BEGIN
                INSERT INTO prompts_fts(rowid, content, title)
                VALUES (new.rowid, new.content, new.title);
            END
        """)

        execute("""
            CREATE TRIGGER IF NOT EXISTS prompts_ad AFTER DELETE ON prompts BEGIN
                INSERT INTO prompts_fts(prompts_fts, rowid, content, title)
                VALUES ('delete', old.rowid, old.content, old.title);
            END
        """)

        execute("""
            CREATE TRIGGER IF NOT EXISTS prompts_au AFTER UPDATE ON prompts BEGIN
                INSERT INTO prompts_fts(prompts_fts, rowid, content, title)
                VALUES ('delete', old.rowid, old.content, old.title);
                INSERT INTO prompts_fts(rowid, content, title)
                VALUES (new.rowid, new.content, new.title);
            END
        """)

        execute("CREATE INDEX IF NOT EXISTS idx_prompts_last_used ON prompts(last_used_at DESC)")
        execute("CREATE INDEX IF NOT EXISTS idx_prompts_use_count ON prompts(use_count DESC)")
    }

    // MARK: - CRUD

    func upsertPrompt(id: String, content: String, title: String, createdAt: Date, lastUsedAt: Date, useCount: Int, isFavorite: Bool, characterCount: Int) {
        queue.sync {
            let sql = """
                INSERT INTO prompts (id, content, title, created_at, last_used_at, use_count, is_favorite, character_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    content = excluded.content,
                    title = excluded.title,
                    last_used_at = excluded.last_used_at,
                    use_count = excluded.use_count,
                    is_favorite = excluded.is_favorite,
                    character_count = excluded.character_count
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                print("[FTSDatabase] upsert準備失敗: \(errorMessage)")
                return
            }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, 1, id)
            bindText(stmt, 2, content)
            bindText(stmt, 3, title)
            sqlite3_bind_double(stmt, 4, createdAt.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 5, lastUsedAt.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 6, Int32(useCount))
            sqlite3_bind_int(stmt, 7, isFavorite ? 1 : 0)
            sqlite3_bind_int(stmt, 8, Int32(characterCount))

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[FTSDatabase] upsert実行失敗: \(errorMessage)")
            }
        }
    }

    func upsertPrompts(_ items: [(id: String, content: String, title: String, createdAt: Date, lastUsedAt: Date, useCount: Int, isFavorite: Bool, characterCount: Int)]) {
        queue.sync {
            execute("BEGIN TRANSACTION")
            let sql = """
                INSERT INTO prompts (id, content, title, created_at, last_used_at, use_count, is_favorite, character_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    content = excluded.content, title = excluded.title,
                    last_used_at = excluded.last_used_at, use_count = excluded.use_count,
                    is_favorite = excluded.is_favorite, character_count = excluded.character_count
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                execute("ROLLBACK")
                return
            }
            defer { sqlite3_finalize(stmt) }

            for item in items {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                bindText(stmt, 1, item.id)
                bindText(stmt, 2, item.content)
                bindText(stmt, 3, item.title)
                sqlite3_bind_double(stmt, 4, item.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 5, item.lastUsedAt.timeIntervalSince1970)
                sqlite3_bind_int(stmt, 6, Int32(item.useCount))
                sqlite3_bind_int(stmt, 7, item.isFavorite ? 1 : 0)
                sqlite3_bind_int(stmt, 8, Int32(item.characterCount))
                sqlite3_step(stmt)
            }
            execute("COMMIT")
        }
    }

    func deletePrompt(id: String) {
        queue.sync {
            let sql = "DELETE FROM prompts WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            bindText(stmt, 1, id)
            sqlite3_step(stmt)
        }
    }

    // MARK: - 検索

    func search(query: String, limit: Int = 20) -> [FTSSearchResult] {
        return queue.sync {
            guard !query.isEmpty else { return [] }

            let ftsQuery = query
                .split(separator: " ")
                .map { "\($0)*" }
                .joined(separator: " ")

            // CTEでMAX(use_count)を事前計算して行ごとのサブクエリを回避
            let sql = """
                WITH max_usage AS (SELECT COALESCE(MAX(use_count), 1) AS val FROM prompts)
                SELECT p.id, p.content, p.title, p.last_used_at, p.use_count, p.is_favorite, p.character_count,
                       bm25(prompts_fts, 1.0, 0.5) as rank
                FROM prompts_fts fts
                JOIN prompts p ON p.rowid = fts.rowid, max_usage
                WHERE prompts_fts MATCH ?
                ORDER BY
                    rank * 0.4 +
                    (CAST(p.use_count AS REAL) / max_usage.val) * 0.3 +
                    (1.0 - (julianday('now') - julianday(p.last_used_at, 'unixepoch')) / 30.0) * 0.2 +
                    p.is_favorite * 0.1
                DESC
                LIMIT ?
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                print("[FTSDatabase] 検索準備失敗: \(errorMessage)")
                return []
            }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, 1, ftsQuery)
            sqlite3_bind_int(stmt, 2, Int32(limit))

            return readResults(from: stmt)
        }
    }

    func fetchRecent(limit: Int = 20) -> [FTSSearchResult] {
        return queue.sync {
            let sql = """
                SELECT id, content, title, last_used_at, use_count, is_favorite, character_count
                FROM prompts ORDER BY last_used_at DESC LIMIT ?
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(limit))
            return readResults(from: stmt)
        }
    }

    func fetchFavorites() -> [FTSSearchResult] {
        return queue.sync {
            let sql = """
                SELECT id, content, title, last_used_at, use_count, is_favorite, character_count
                FROM prompts WHERE is_favorite = 1 ORDER BY last_used_at DESC
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            return readResults(from: stmt)
        }
    }

    func rebuildIndex() {
        queue.sync {
            execute("INSERT INTO prompts_fts(prompts_fts) VALUES('rebuild')")
        }
    }

    // MARK: - ユーティリティ

    private func readResults(from stmt: OpaquePointer?) -> [FTSSearchResult] {
        var results: [FTSSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(stmt, 0),
                  let contentPtr = sqlite3_column_text(stmt, 1),
                  let titlePtr = sqlite3_column_text(stmt, 2) else {
                continue
            }
            let columnCount = sqlite3_column_count(stmt)
            let result = FTSSearchResult(
                id: String(cString: idPtr),
                content: String(cString: contentPtr),
                title: String(cString: titlePtr),
                lastUsedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                useCount: Int(sqlite3_column_int(stmt, 4)),
                isFavorite: sqlite3_column_int(stmt, 5) != 0,
                characterCount: Int(sqlite3_column_int(stmt, 6)),
                relevanceScore: columnCount > 7 ? sqlite3_column_double(stmt, 7) : 0
            )
            results.append(result)
        }
        return results
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "不明なエラー"
            print("[FTSDatabase] SQL実行失敗: \(msg)")
            sqlite3_free(errMsg)
        }
    }

    private var errorMessage: String {
        db.map { String(cString: sqlite3_errmsg($0)) } ?? "データベース未接続"
    }
}

// MARK: - 検索結果モデル

struct FTSSearchResult: Identifiable, Sendable {
    let id: String
    let content: String
    let title: String
    let lastUsedAt: Date
    let useCount: Int
    let isFavorite: Bool
    let characterCount: Int
    let relevanceScore: Double
}
