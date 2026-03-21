import AppKit
import SwiftUI
import SwiftData

// MARK: - アプリデリゲート

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var overlayController: OverlayPanelController?
    private var accessibilityManager: AccessibilityManager?
    private var onboardingWindow: NSWindow?
    private var lastOverlayState = false

    let appState = AppState()

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
        appState.searchEngine.configure(with: modelContainer)

        accessibilityManager = AccessibilityManager(appState: appState)

        overlayController = OverlayPanelController(
            appState: appState,
            modelContainer: modelContainer
        )

        hotkeyManager = HotkeyManager(appState: appState)

        if accessibilityManager?.checkAccessibility() == true {
            appState.isAccessibilityGranted = true
            hotkeyManager?.start()
        } else {
            showAccessibilityOnboarding()
        }

        startOverlayObservation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
    }

    // MARK: - オーバーレイ状態監視 (ポーリング方式で安全に)

    private func startOverlayObservation() {
        // withObservationTrackingの再帰パターンは不安定なため、
        // 軽量タイマーで状態変化を検出する
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = self.appState.isOverlayVisible
            if current != self.lastOverlayState {
                self.lastOverlayState = current
                if current {
                    self.overlayController?.show()
                } else {
                    self.overlayController?.hide()
                }
            }
        }
    }

    // MARK: - オンボーディング

    private func showAccessibilityOnboarding() {
        accessibilityManager?.startPolling { [weak self] in
            guard let self else { return }
            self.appState.isAccessibilityGranted = true
            self.hotkeyManager?.start()
            // SwiftUIの再描画を完了させてからウィンドウを閉じる
            DispatchQueue.main.async { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
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
                onGranted: { [weak self] in
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                }
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
