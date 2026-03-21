import SwiftUI
import SwiftData

@main
struct pro_mptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 設定画面
        Settings {
            SettingsView()
                .modelContainer(appDelegate.modelContainer)
        }

        // メニューバーアイコン
        MenuBarExtra("pro-mpt", systemImage: "text.bubble") {
            MenuBarView(appState: appDelegate.appState)
        }
    }
}
