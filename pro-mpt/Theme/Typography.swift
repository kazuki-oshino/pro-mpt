import SwiftUI

// MARK: - pro-mpt タイポグラフィシステム

enum AppTypography {
    // プロンプト入力/表示 (SF Mono)
    static let promptEditor = Font.system(size: 14, design: .monospaced)
    static let promptEditorSmall = Font.system(size: 12, design: .monospaced)

    // UI ラベル (SF Pro)
    static let label = Font.system(size: 13)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSemibold = Font.system(size: 13, weight: .semibold)

    // ショートカットヒント
    static let shortcutHint = Font.system(size: 11, weight: .medium)

    // 検索結果
    static let resultTitle = Font.system(size: 14, weight: .semibold)
    static let resultPreview = Font.system(size: 12, design: .monospaced)

    // メタデータ
    static let metadata = Font.system(size: 11)
    static let metadataMono = Font.system(size: 11, design: .monospaced)

    // ヘッダー
    static let sectionHeader = Font.system(size: 11, weight: .semibold)
}

// MARK: - デザイン定数

enum AppLayout {
    // パネル
    static let panelWidth: CGFloat = 680
    static let panelCornerRadius: CGFloat = 16
    static let inputCornerRadius: CGFloat = 10
    static let itemCornerRadius: CGFloat = 8

    // スペーシング
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 12
    static let paddingLarge: CGFloat = 16

    // 入力エリア
    static let inputMinHeight: CGFloat = 100
    static let inputMaxHeight: CGFloat = 288  // 12行相当

    // 履歴リスト
    static let maxVisibleHistoryItems = 8
    static let maxVisibleTodoItems = 30
    static let historyItemHeight: CGFloat = 44

    // アニメーション
    static let showDuration: Double = 0.15
    static let hideDuration: Double = 0.10
    static let feedbackDuration: Double = 0.30
}
