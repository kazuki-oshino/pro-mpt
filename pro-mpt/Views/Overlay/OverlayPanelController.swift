import AppKit
import SwiftUI
import SwiftData

// MARK: - フローティングオーバーレイパネル管理

final class OverlayPanelController {
    private let appState: AppState
    private let modelContainer: ModelContainer
    private lazy var modelContext = ModelContext(modelContainer)
    private var panel: NSPanel?
    private var localMonitor: Any?

    init(appState: AppState, modelContainer: ModelContainer) {
        self.appState = appState
        self.modelContainer = modelContainer
        setupPanel()
    }

    // MARK: - パネル初期化

    private func setupPanel() {
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: AppLayout.panelWidth, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.hidesOnDeactivate = false

        let contentView = OverlayContentView(appState: appState)
            .modelContainer(modelContainer)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        self.panel = panel
    }

    // MARK: - 表示/非表示

    func show() {
        guard let panel else { return }

        positionPanel()
        removeLocalKeyMonitor()

        // IMEを動作させるためにアプリをアクティブ化
        NSApp.activate(ignoringOtherApps: true)

        panel.alphaValue = 0
        panel.setFrame(panel.frame.offsetBy(dx: 0, dy: 8), display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppLayout.showDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: -8), display: true)
        }

        setupLocalKeyMonitor()
    }

    func hide() {
        guard let panel, panel.isVisible else { return }

        removeLocalKeyMonitor()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AppLayout.hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })

        // AppDelegateのタイマーが状態変化を検出してhide()を呼ぶので、
        // ここでは直接状態を同期するだけ (再入しない)
        appState.isOverlayVisible = false
    }

    // MARK: - マルチモニター対応

    private func positionPanel() {
        guard let panel else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
        let y = screenFrame.origin.y + screenFrame.height * 0.75 - panelSize.height / 2

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - キーボードイベント

    private func setupLocalKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event)
        }
    }

    private func removeLocalKeyMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)

        switch event.keyCode {

        case 53: // Escape
            if appState.mode == .search {
                appState.exitSearchMode()
            } else {
                appState.isOverlayVisible = false
            }
            return nil

        case 40 where hasCmd: // ⌘+K
            if appState.mode == .search {
                appState.exitSearchMode()
            } else {
                appState.enterSearchMode()
            }
            return nil

        case 64: // F17 → コピーして閉じる
            handleCopyAndClose()
            return nil

        case 64 where hasShift: // Shift+F17 → コピーして前のアプリにペースト
            handleCopyPasteAndClose()
            return nil

        // Shift+Enter (アイテム選択中): 入力欄に挿入 — Enter より先に判定
        case 36 where hasShift && appState.selectedHistoryIndex >= 0:
            handleInsertSelected()
            return nil

        // Enter (アイテム選択中): コピーして閉じる
        case 36 where appState.selectedHistoryIndex >= 0:
            handleCopySelectedAndClose()
            return nil

        case 125 where appState.mode == .search: // ↓ (検索モードのみ)
            appState.selectNext()
            return nil

        case 126 where appState.mode == .search: // ↑ (検索モードのみ)
            appState.selectPrevious()
            return nil

        case 45 where hasCmd: // ⌘+N
            appState.clearInput()
            return nil

        case 3 where hasCmd: // ⌘+F
            handleToggleFavorite()
            return nil

        case 51 where hasCmd: // ⌘+Delete
            handleDeleteSelected()
            return nil

        default:
            return event
        }
    }

    // MARK: - テキスト取得ヘルパー

    private func resolveText() -> String? {
        if appState.selectedHistoryIndex >= 0, let result = selectedResult() {
            return result.content
        }
        let text = appState.promptText
        return text.isEmpty ? nil : text
    }

    private func selectedResult() -> FTSSearchResult? {
        let results = appState.searchEngine.searchResults
        let index = appState.selectedHistoryIndex
        guard index >= 0, index < results.count else { return nil }
        return results[index]
    }

    // MARK: - アクション

    private func handleCopyAndClose() {
        guard let text = resolveText() else { return }
        ClipboardManager.copy(text)
        saveOrUpdatePrompt(content: text)
        showFeedbackAndClose()
    }

    private func handleCopySelectedAndClose() {
        guard let result = selectedResult() else { return }
        ClipboardManager.copy(result.content)
        updatePromptUsage(id: result.id)
        showFeedbackAndClose()
    }

    private func handleInsertSelected() {
        guard let result = selectedResult() else { return }
        appState.exitSearchMode()
        appState.insertAtCursor(result.content)
    }

    private func handleCopyPasteAndClose() {
        guard let text = resolveText() else { return }
        ClipboardManager.copy(text)
        saveOrUpdatePrompt(content: text)

        appState.showCopiedFeedback()
        DispatchQueue.main.asyncAfter(deadline: .now() + AppLayout.feedbackDuration) { [weak self] in
            self?.appState.promptText = ""
            self?.appState.isOverlayVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.simulatePaste()
            }
        }
    }

    private func handleToggleFavorite() {
        guard let result = selectedResult(),
              let prompt = findPrompt(byId: result.id) else { return }
        prompt.isFavorite.toggle()
        saveContext()
        appState.searchEngine.indexPrompt(prompt)
    }

    private func handleDeleteSelected() {
        guard let result = selectedResult(),
              let prompt = findPrompt(byId: result.id) else { return }
        modelContext.delete(prompt)
        saveContext()
        appState.searchEngine.removeFromIndex(id: result.id)
        appState.selectedHistoryIndex = -1
    }

    // MARK: - データ操作ヘルパー

    private func findPrompt(byId id: String) -> Prompt? {
        let descriptor = FetchDescriptor<Prompt>()
        guard let prompts = try? modelContext.fetch(descriptor) else { return nil }
        return prompts.first(where: { $0.promptId.uuidString == id })
    }

    /// 同じ内容のプロンプトがあれば使用記録を更新、なければ新規作成
    private func saveOrUpdatePrompt(content: String) {
        let descriptor = FetchDescriptor<Prompt>()
        if let prompts = try? modelContext.fetch(descriptor),
           let existing = prompts.first(where: { $0.content == content }) {
            existing.recordUsage()
        } else {
            let prompt = Prompt(content: content)
            modelContext.insert(prompt)
        }
        saveContext()

        // FTSインデックスを更新
        if let prompts = try? modelContext.fetch(descriptor),
           let saved = prompts.first(where: { $0.content == content }) {
            appState.searchEngine.indexPrompt(saved)
        }
    }

    private func updatePromptUsage(id: String) {
        guard let prompt = findPrompt(byId: id) else { return }
        prompt.recordUsage()
        saveContext()
        appState.searchEngine.indexPrompt(prompt)
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("[OverlayPanelController] 保存失敗: \(error)")
        }
    }

    private func showFeedbackAndClose() {
        appState.showCopiedFeedback()
        DispatchQueue.main.asyncAfter(deadline: .now() + AppLayout.feedbackDuration) { [weak self] in
            self?.appState.promptText = ""
            self?.appState.isOverlayVisible = false
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
    }
}

// MARK: - カスタム NSPanel

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
