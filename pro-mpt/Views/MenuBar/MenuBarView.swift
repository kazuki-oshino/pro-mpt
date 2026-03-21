import SwiftUI

// MARK: - メニューバーメニュー

struct MenuBarView: View {
    let appState: AppState

    var body: some View {
        Button("プロンプトを開く (F16)") {
            appState.toggleOverlay()
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])

        Divider()

        Button("終了") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
