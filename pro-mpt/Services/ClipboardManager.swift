import Cocoa

// MARK: - クリップボード操作

enum ClipboardManager {
    /// テキストをクリップボードにコピー
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// クリップボードからテキストを取得
    static func paste() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
}
