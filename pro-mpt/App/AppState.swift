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

    enum InputMode {
        case input
        case search
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
            searchEngine.refreshCache()
        }
    }

    func enterSearchMode() {
        mode = .search
        searchQuery = ""
        selectedHistoryIndex = -1
    }

    func exitSearchMode() {
        mode = .input
        searchQuery = ""
        selectedHistoryIndex = -1
    }

    func clearInput() {
        promptText = ""
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
