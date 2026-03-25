import Foundation

// MARK: - TODO ファイル読み書きサービス

final class TodoService {
    private let filePath: String

    init(filePath: String) {
        self.filePath = filePath
    }

    /// ファイルパスが設定されているか
    var isConfigured: Bool {
        !filePath.isEmpty
    }

    // MARK: - 読み取り

    /// 未完了TODOのみを取得（ファイル末尾が先頭 = 新しい順）
    func fetchIncompleteTodos() -> [TodoItem] {
        guard isConfigured else { return [] }

        let url = URL(fileURLWithPath: filePath)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        let lines = content.components(separatedBy: "\n")
        var items: [TodoItem] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // インデント付き（サブタスク）はスキップ
            if line.hasPrefix("\t") || line.hasPrefix("  ") {
                // ただし行頭が `- [` で始まる場合のみタスク行と判定
                // インデントありならスキップ
                if line != trimmed { continue }
            }

            // 未完了タスクのみ抽出
            if trimmed.hasPrefix("- [ ] ") {
                let text = String(trimmed.dropFirst(6))
                items.append(TodoItem(
                    text: text,
                    isCompleted: false,
                    lineNumber: index
                ))
            }
        }

        // ファイル上部が先頭（古い順）
        return items
    }

    // MARK: - 追加

    /// ファイル末尾にTODOを追加
    func addTodo(text: String) throws {
        guard isConfigured else { return }

        let url = URL(fileURLWithPath: filePath)
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

        // 末尾に改行がなければ追加
        if !content.isEmpty && !content.hasSuffix("\n") {
            content += "\n"
        }

        content += "- [ ] \(text)\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - 完了

    /// TODOを完了にする
    func completeTodo(_ item: TodoItem) throws {
        try modifyLine(at: item.lineNumber) { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- [ ] ") else { return line }
            let text = String(trimmed.dropFirst(6))
            return "- [x] \(text)"
        }
    }

    // MARK: - 更新

    /// TODOのテキストを変更
    func updateTodo(_ item: TodoItem, newText: String) throws {
        try modifyLine(at: item.lineNumber) { _ in
            "- [ ] \(newText)"
        }
    }

    // MARK: - 削除

    /// TODOを削除（行を削除）
    func deleteTodo(_ item: TodoItem) throws {
        guard isConfigured else { return }

        let url = URL(fileURLWithPath: filePath)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        var lines = content.components(separatedBy: "\n")
        guard item.lineNumber >= 0, item.lineNumber < lines.count else { return }

        lines.remove(at: item.lineNumber)
        let result = lines.joined(separator: "\n")
        try result.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - ヘルパー

    private func modifyLine(at lineNumber: Int, transform: (String) -> String) throws {
        guard isConfigured else { return }

        let url = URL(fileURLWithPath: filePath)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        var lines = content.components(separatedBy: "\n")
        guard lineNumber >= 0, lineNumber < lines.count else { return }

        lines[lineNumber] = transform(lines[lineNumber])
        let result = lines.joined(separator: "\n")
        try result.write(to: url, atomically: true, encoding: .utf8)
    }
}
