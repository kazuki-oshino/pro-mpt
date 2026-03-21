import SwiftUI
import AppKit

// MARK: - NSTextViewのカーソル位置を読み取るユーティリティ

enum TextViewHelper {
    /// ビュー階層からNSTextViewを探す
    static func findNSTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        for subview in view.subviews {
            if let found = findNSTextView(in: subview) {
                return found
            }
        }
        return nil
    }

    /// キーウィンドウのNSTextViewからカーソル位置(UTF-16オフセット)を取得
    static func currentCursorOffset() -> Int? {
        guard let window = NSApp.keyWindow,
              let textView = findNSTextView(in: window.contentView ?? NSView()) else {
            return nil
        }
        return textView.selectedRange().location
    }

    /// キーウィンドウのNSTextViewにカーソル位置を設定してフォーカスを当てる
    static func setCursorOffset(_ offset: Int) {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow,
                  let textView = findNSTextView(in: window.contentView ?? NSView()) else {
                return
            }
            let safeOffset = min(offset, (textView.string as NSString).length)
            window.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: safeOffset, length: 0))
        }
    }
}
