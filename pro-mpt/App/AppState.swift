import SwiftUI
import Observation

// MARK: - アプリ全体の状態管理

@Observable
final class AppState {
    var isOverlayVisible = false
    var mode: InputMode = .input
    var promptText = ""
    var searchQuery = ""
    var selectedHistoryIndex = -1
    var showCopyFeedback = false
    var isAccessibilityGranted = false

    let searchEngine = SearchEngine()

    // MARK: - TODO関連
    var todoItems: [TodoItem] = []
    var todoInputText = ""
    var editingTodoId: UUID?
    var selectedTodoIndex = -1

    /// 検索モードに入る前のカーソル位置 (UTF-16オフセット)
    private var savedCursorOffset: Int = 0

    enum InputMode {
        case input
        case search
        case favorite
        case todo
    }

    var visibleItemCount: Int {
        min(searchEngine.searchResults.count, AppLayout.maxVisibleHistoryItems)
    }

    // MARK: - オーバーレイ操作

    func toggleOverlay() {
        isOverlayVisible.toggle()
        if isOverlayVisible {
            mode = .input
            selectedHistoryIndex = -1
            selectedTodoIndex = -1
            todoInputText = ""
            editingTodoId = nil
            searchEngine.refreshCache()
        }
    }

    func enterSearchMode() {
        // NSTextViewから直接カーソル位置を取得
        savedCursorOffset = TextViewHelper.currentCursorOffset()
            ?? (promptText as NSString).length
        mode = .search
        searchQuery = ""
        selectedHistoryIndex = -1
        searchEngine.refreshCache()
    }

    func exitSearchMode() {
        mode = .input
        searchQuery = ""
        selectedHistoryIndex = -1
        // TextEditorが再表示された後にカーソルを復元
        TextViewHelper.setCursorOffset(savedCursorOffset)
    }

    func enterFavoriteMode() {
        savedCursorOffset = TextViewHelper.currentCursorOffset()
            ?? (promptText as NSString).length
        mode = .favorite
        searchQuery = ""
        selectedHistoryIndex = -1
        searchEngine.refreshFavorites()
    }

    func exitFavoriteMode() {
        mode = .input
        searchQuery = ""
        selectedHistoryIndex = -1
        TextViewHelper.setCursorOffset(savedCursorOffset)
    }

    // MARK: - TODOモード

    func enterTodoMode() {
        savedCursorOffset = TextViewHelper.currentCursorOffset()
            ?? (promptText as NSString).length
        mode = .todo
        todoInputText = ""
        editingTodoId = nil
        selectedTodoIndex = -1
        refreshTodos()
    }

    func exitTodoMode() {
        mode = .input
        editingTodoId = nil
        selectedTodoIndex = -1
        TextViewHelper.setCursorOffset(savedCursorOffset)
    }

    func refreshTodos() {
        let path = UserDefaults.standard.string(forKey: "todoFilePath") ?? ""
        let service = TodoService(filePath: path)
        todoItems = service.fetchIncompleteTodos()
    }

    var todoVisibleItemCount: Int {
        min(todoItems.count, AppLayout.maxVisibleTodoItems)
    }

    func selectNextTodo() {
        if selectedTodoIndex < todoVisibleItemCount - 1 {
            selectedTodoIndex += 1
        }
    }

    func selectPreviousTodo() {
        if selectedTodoIndex > -1 {
            selectedTodoIndex -= 1
        }
    }

    func clearInput() {
        promptText = ""
    }

    // MARK: - カーソル位置でのテキスト挿入

    func insertAtCursor(_ insertText: String) {
        let nsText = promptText as NSString
        let safeOffset = min(savedCursorOffset, nsText.length)
        let result = nsText.replacingCharacters(
            in: NSRange(location: safeOffset, length: 0),
            with: insertText
        )
        promptText = result
        // 挿入テキストの末尾にカーソルを移動
        let newOffset = safeOffset + (insertText as NSString).length
        TextViewHelper.setCursorOffset(newOffset)
    }

    // MARK: - キーボードナビゲーション

    func selectNext() {
        if selectedHistoryIndex < visibleItemCount - 1 {
            selectedHistoryIndex += 1
        }
    }

    func selectPrevious() {
        if selectedHistoryIndex > -1 {
            selectedHistoryIndex -= 1
        }
    }

    // MARK: - フィードバック

    func showCopiedFeedback() {
        showCopyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + AppLayout.feedbackDuration) { [weak self] in
            self?.showCopyFeedback = false
        }
    }
}
