import Foundation

// MARK: - TODOデータモデル

struct TodoItem: Identifiable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var lineNumber: Int

    init(id: UUID = UUID(), text: String, isCompleted: Bool, lineNumber: Int) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.lineNumber = lineNumber
    }
}
