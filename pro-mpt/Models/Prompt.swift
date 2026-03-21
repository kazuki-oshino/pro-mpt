import Foundation
import SwiftData

// MARK: - プロンプトデータモデル

@Model
final class Prompt {
    /// 安定したID (hashValueの代わりに使用)
    @Attribute(.unique) var promptId: UUID

    var content: String
    var title: String
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int
    var isFavorite: Bool
    var tags: [String]

    var characterCount: Int {
        content.count
    }

    init(content: String) {
        self.promptId = UUID()
        self.content = content
        self.title = Prompt.generateTitle(from: content)
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.useCount = 1
        self.isFavorite = false
        self.tags = []
    }

    static func generateTitle(from content: String) -> String {
        let cleaned = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(80))
    }

    func recordUsage() {
        lastUsedAt = Date()
        useCount += 1
    }

    func updateContent(_ newContent: String) {
        content = newContent
        title = Prompt.generateTitle(from: newContent)
    }
}
