import AppKit
import SwiftUI
import SwiftData

// MARK: - アプリデリゲート

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var overlayController: OverlayPanelController?
    private var accessibilityManager: AccessibilityManager?
    private var onboardingWindow: NSWindow?

    let appState = AppState()

    // SwiftData コンテナ
    lazy var modelContainer: ModelContainer = {
        let schema = Schema([Prompt.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainerの作成に失敗: \(error)")
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 検索エンジンにModelContainerを設定
        appState.searchEngine.configure(with: modelContainer)

        // アクセシビリティ管理の初期化
        accessibilityManager = AccessibilityManager(appState: appState)

        // オーバーレイパネルの初期化
        overlayController = OverlayPanelController(
            appState: appState,
            modelContainer: modelContainer
        )

        // ホットキー管理の初期化
        hotkeyManager = HotkeyManager(appState: appState)

        // アクセシビリティ権限を確認
        if accessibilityManager?.checkAccessibility() == true {
            appState.isAccessibilityGranted = true
            hotkeyManager?.start()
        } else {
            showAccessibilityOnboarding()
        }

        // オーバーレイ表示状態の監視
        observeOverlayState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
    }

    // MARK: - オーバーレイ状態監視

    private func observeOverlayState() {
        withObservationTracking {
            _ = appState.isOverlayVisible
        } onChange: { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.appState.isOverlayVisible {
                    self.overlayController?.show()
                } else {
                    self.overlayController?.hide()
                }
                self.observeOverlayState()
            }
        }
    }

    // MARK: - オンボーディング

    private func showAccessibilityOnboarding() {
        accessibilityManager?.startPolling { [weak self] in
            guard let self else { return }
            self.appState.isAccessibilityGranted = true
            self.hotkeyManager?.start()
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "pro-mpt セットアップ"
        window.center()
        window.contentView = NSHostingView(
            rootView: AccessibilityOnboardingView(
                appState: appState,
                onGranted: { [weak window] in
                    window?.close()
                }
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
