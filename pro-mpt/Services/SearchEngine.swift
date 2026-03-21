import Foundation
import SwiftData

// MARK: - ハイブリッド検索エンジン

@Observable
final class SearchEngine {
    private let ftsDatabase: FTSDatabase
    private var modelContainer: ModelContainer?

    private(set) var cachedPrompts: [FTSSearchResult] = []
    private(set) var searchResults: [FTSSearchResult] = []

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

        // 短いクエリ(1-2文字)はインメモリ、それ以外はFTS5のみ
        if trimmed.count <= 2 {
            searchResults = cachedPrompts.filter { result in
                result.content.localizedCaseInsensitiveContains(trimmed) ||
                result.title.localizedCaseInsensitiveContains(trimmed)
            }
        } else {
            searchResults = ftsDatabase.search(query: trimmed)
        }
    }

    // MARK: - キャッシュ

    func refreshCache() {
        cachedPrompts = ftsDatabase.fetchRecent(limit: 50)
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
        refreshCache()
    }

    func removeFromIndex(id: String) {
        ftsDatabase.deletePrompt(id: id)
        refreshCache()
    }
}
