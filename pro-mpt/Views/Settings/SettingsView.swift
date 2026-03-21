import SwiftUI

// MARK: - 設定画面

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
        }
        .frame(width: 400, height: 200)
    }
}

// MARK: - 一般設定

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("ホットキー") {
                HStack {
                    Text("起動キー")
                    Spacer()
                    Text("F16")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section("情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
