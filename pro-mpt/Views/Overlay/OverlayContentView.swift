import SwiftUI
import SwiftData

// MARK: - オーバーレイのメインView

struct OverlayContentView: View {
    @Bindable var appState: AppState
    @FocusState private var focusedField: FocusField?

    enum FocusField {
        case editor, search
    }

    /// 検索/お気に入りモードかどうか
    private var isListMode: Bool {
        appState.mode == .search || appState.mode == .favorite
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                modeBar
                divider
                editorArea
                if isListMode {
                    divider
                    historySection
                }
                divider
                statusBar
            }
        }
        .frame(width: AppLayout.panelWidth)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.panelCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.panelCornerRadius)
                .strokeBorder(AppColors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
        .onAppear {
            focusedField = .editor
        }
        .onChange(of: appState.searchQuery) { _, newValue in
            appState.searchEngine.search(query: newValue)
        }
        .onChange(of: appState.mode) { _, newMode in
            focusedField = newMode == .input ? .editor : .search
        }
    }

    // MARK: - 背景

    private var backgroundLayer: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            AppColors.overlayBackground
        }
    }

    // MARK: - モードバー

    private var modeBar: some View {
        HStack(spacing: AppLayout.paddingSmall) {
            modeButton(title: "入力", icon: "pencil", isActive: appState.mode == .input) {
                if appState.mode == .search {
                    appState.exitSearchMode()
                } else if appState.mode == .favorite {
                    appState.exitFavoriteMode()
                }
            }
            modeButton(title: "検索", icon: "magnifyingglass", shortcut: "⌘K", isActive: appState.mode == .search) {
                appState.enterSearchMode()
            }
            modeButton(title: "お気に入り", icon: "star", shortcut: "⌘O", isActive: appState.mode == .favorite) {
                appState.enterFavoriteMode()
            }

            Spacer()

            if appState.mode == .input {
                Text("\(appState.promptText.count)文字")
                    .font(AppTypography.metadata)
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                ResultCountLabel(count: appState.searchEngine.searchResults.count)
            }
        }
        .padding(.horizontal, AppLayout.paddingLarge)
        .padding(.vertical, AppLayout.paddingSmall)
    }

    private func modeButton(title: String, icon: String, shortcut: String? = nil, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(AppTypography.shortcutHint)
                if let shortcut {
                    Text(shortcut)
                        .font(AppTypography.metadata)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isActive ? AppColors.surface : Color.clear)
            .foregroundStyle(isActive ? AppColors.textPrimary : AppColors.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - エディタ

    private var editorArea: some View {
        Group {
            if isListMode {
                searchField
            } else {
                promptEditor
            }
        }
    }

    private var promptEditor: some View {
        ZStack(alignment: .topLeading) {
            if appState.promptText.isEmpty {
                Text("プロンプトを入力...")
                    .font(AppTypography.promptEditor)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.horizontal, AppLayout.paddingLarge + 5)
                    .padding(.vertical, AppLayout.paddingMedium + 2)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $appState.promptText)
                .font(AppTypography.promptEditor)
                .foregroundStyle(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .editor)
                .frame(minHeight: AppLayout.inputMinHeight, maxHeight: AppLayout.inputMaxHeight)
                .padding(.horizontal, AppLayout.paddingMedium)
                .padding(.vertical, AppLayout.paddingSmall)
        }
        .background(AppColors.bgBase)
    }

    private var searchField: some View {
        HStack(spacing: AppLayout.paddingSmall) {
            Image(systemName: appState.mode == .favorite ? "star" : "magnifyingglass")
                .foregroundStyle(AppColors.accent)
                .font(.system(size: 14))

            TextField(appState.mode == .favorite ? "お気に入りを検索..." : "検索...", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .font(AppTypography.promptEditor)
                .foregroundStyle(AppColors.textPrimary)
                .focused($focusedField, equals: .search)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        focusedField = .search
                    }
                }
        }
        .padding(.horizontal, AppLayout.paddingLarge)
        .padding(.vertical, AppLayout.paddingMedium)
        .background(AppColors.bgBase)
    }

    // MARK: - 履歴セクション

    private var historySection: some View {
        let results = appState.searchEngine.searchResults

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(sectionTitle)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textTertiary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, AppLayout.paddingLarge)
            .padding(.vertical, AppLayout.paddingSmall)

            if results.isEmpty {
                emptyState
            } else {
                let visible = results.prefix(AppLayout.maxVisibleHistoryItems)
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, result in
                    PromptRowView(
                        result: result,
                        isSelected: appState.selectedHistoryIndex == index,
                        searchQuery: isListMode ? appState.searchQuery : ""
                    )
                    .contentShape(Rectangle())
                    // ダブルクリックを先に判定
                    .onTapGesture(count: 2) {
                        ClipboardManager.copy(result.content)
                        appState.showCopiedFeedback()
                    }
                    .onTapGesture {
                        appState.selectedHistoryIndex = index
                    }
                }
            }
        }
        .frame(minHeight: 60)
    }

    private var sectionTitle: String {
        if appState.mode == .favorite {
            return appState.searchQuery.isEmpty ? "お気に入り" : "検索結果"
        }
        return appState.searchQuery.isEmpty ? "最近の履歴" : "検索結果"
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.textTertiary.opacity(0.5))
                Text(emptyStateMessage)
                    .font(AppTypography.label)
                    .foregroundStyle(AppColors.textTertiary)
                if isListMode && !appState.searchQuery.isEmpty {
                    Text("キーワードを変えて検索してください")
                        .font(AppTypography.metadata)
                        .foregroundStyle(AppColors.textTertiary.opacity(0.6))
                }
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var emptyStateIcon: String {
        if appState.mode == .favorite { return "star" }
        if appState.mode == .search { return "magnifyingglass" }
        return "text.bubble"
    }

    private var emptyStateMessage: String {
        if appState.mode == .favorite {
            return appState.searchQuery.isEmpty ? "お気に入りがありません" : "一致するお気に入りがありません"
        }
        if appState.mode == .search {
            return appState.searchQuery.isEmpty ? "まだ履歴がありません" : "一致するプロンプトがありません"
        }
        return "まだ履歴がありません"
    }

    // MARK: - ステータスバー

    private var statusBar: some View {
        HStack(spacing: AppLayout.paddingLarge) {
            if appState.showCopyFeedback {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Text("コピーしました")
                        .foregroundStyle(AppColors.success)
                }
                .font(AppTypography.shortcutHint)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity
                ))
            } else if appState.selectedHistoryIndex >= 0 {
                ShortcutHintView(key: "↩", action: "入力欄に挿入")
                ShortcutHintView(key: "⌘↩", action: "コピーして閉じる")
                ShortcutHintView(key: "⌘F", action: "お気に入り")
                ShortcutHintView(key: "⌘⌫", action: "削除")
            } else {
                ShortcutHintView(key: "⌘↩", action: "コピーして閉じる")
                ShortcutHintView(key: "⇧F17", action: "ペースト")
                ShortcutHintView(key: "⌘K", action: "検索")
                ShortcutHintView(key: "⌘O", action: "お気に入り")
                ShortcutHintView(key: "esc", action: "閉じる")
            }

            Spacer()
        }
        .padding(.horizontal, AppLayout.paddingLarge)
        .padding(.vertical, AppLayout.paddingSmall)
        .animation(.easeInOut(duration: 0.15), value: appState.showCopyFeedback)
        .animation(.easeInOut(duration: 0.15), value: appState.selectedHistoryIndex)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(height: 0.5)
    }
}

// MARK: - 件数ラベル (再描画を分離)

private struct ResultCountLabel: View {
    let count: Int
    var body: some View {
        Text("\(count)件")
            .font(AppTypography.metadata)
            .foregroundStyle(AppColors.textTertiary)
    }
}

// MARK: - 日付の相対表示

extension Date {
    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var relativeDescription: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "たった今" }
        if interval < 3600 { return "\(Int(interval / 60))分前" }
        if interval < 86400 { return "\(Int(interval / 3600))時間前" }
        if interval < 604800 { return "\(Int(interval / 86400))日前" }
        return Self.shortFormatter.string(from: self)
    }
}
