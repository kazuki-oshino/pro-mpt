import Cocoa

// MARK: - アクセシビリティ権限管理

final class AccessibilityManager {
    private let appState: AppState
    private var pollingTimer: Timer?

    init(appState: AppState) {
        self.appState = appState
    }

    deinit {
        stopPolling()
    }

    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func startPolling(onGranted: @escaping () -> Void) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.checkAccessibility() else { return }
            self.stopPolling()
            DispatchQueue.main.async {
                onGranted()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}
