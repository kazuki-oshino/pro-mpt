import Foundation
import SwiftData

// MARK: - ハイブリッド検索エンジン

@Observable
final class SearchEngine {
    private let ftsDatabase: FTSDatabase
    private var modelContainer: ModelContainer?

    /// 現在の検索対象キャッシュ（モードにより切り替わる）
    private(set) var cachedPrompts: [FTSSearchResult] = []
    private(set) var searchResults: [FTSSearchResult] = []

    /// お気に入りモードかどうか
    private var isFavoriteMode = false

    private let debouncer = Debouncer(delay: 0.05)

    init() {
        ftsDatabase = FTSDatabase()
    }

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        syncFromSwiftData()
    }

    // MARK: - 検索

    func search(query: String) {
        debouncer.debounce { [weak self] in
            self?.performSearch(query: query)
        }
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            searchResults = cachedPrompts
            return
        }

        // インメモリ部分一致検索（中間一致対応）
        var filtered = cachedPrompts.filter { result in
            result.content.localizedCaseInsensitiveContains(trimmed) ||
            result.title.localizedCaseInsensitiveContains(trimmed)
        }

        // 検索モード時はお気に入りを優先表示
        if !isFavoriteMode {
            filtered.sort { a, b in
                if a.isFavorite != b.isFavorite { return a.isFavorite }
                return a.lastUsedAt > b.lastUsedAt
            }
        }

        searchResults = filtered
    }

    // MARK: - キャッシュ

    func refreshCache() {
        isFavoriteMode = false
        cachedPrompts = ftsDatabase.fetchRecent(limit: 10000)
        searchResults = cachedPrompts
    }

    func refreshFavorites() {
        isFavoriteMode = true
        cachedPrompts = ftsDatabase.fetchFavorites()
        searchResults = cachedPrompts
    }

    // MARK: - SwiftData同期

    func syncFromSwiftData() {
        guard let container = modelContainer else { return }

        Task.detached { [ftsDatabase] in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Prompt>(
                sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
            )

            do {
                let prompts = try context.fetch(descriptor)
                let items = prompts.map { prompt in (
                    id: prompt.promptId.uuidString,
                    content: prompt.content,
                    title: prompt.title,
                    createdAt: prompt.createdAt,
                    lastUsedAt: prompt.lastUsedAt,
                    useCount: prompt.useCount,
                    isFavorite: prompt.isFavorite,
                    characterCount: prompt.content.count
                )}
                ftsDatabase.upsertPrompts(items)
                await MainActor.run { [weak self] in
                    self?.refreshCache()
                }
            } catch {
                print("[SearchEngine] SwiftData同期失敗: \(error)")
            }
        }
    }

    func indexPrompt(_ prompt: Prompt) {
        ftsDatabase.upsertPrompt(
            id: prompt.promptId.uuidString,
            content: prompt.content,
            title: prompt.title,
            createdAt: prompt.createdAt,
            lastUsedAt: prompt.lastUsedAt,
            useCount: prompt.useCount,
            isFavorite: prompt.isFavorite,
            characterCount: prompt.content.count
        )
        if isFavoriteMode {
            refreshFavorites()
        } else {
            refreshCache()
        }
    }

    func removeFromIndex(id: String) {
        ftsDatabase.deletePrompt(id: id)
        if isFavoriteMode {
            refreshFavorites()
        } else {
            refreshCache()
        }
    }
}
