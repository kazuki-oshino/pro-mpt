import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 設定画面

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
        }
        .frame(width: 480, height: 280)
    }
}

// MARK: - 一般設定

struct GeneralSettingsView: View {
    @AppStorage("todoFilePath") private var todoFilePath = ""

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

            Section("TODO") {
                HStack {
                    TextField("TODOファイルの絶対パス", text: $todoFilePath)
                        .textFieldStyle(.roundedBorder)
                    Button("選択...") {
                        selectTodoFile()
                    }
                }
                if !todoFilePath.isEmpty {
                    Text(todoFilePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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

    private func selectTodoFile() {
        let panel = NSOpenPanel()
        panel.title = "TODOファイルを選択"
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            todoFilePath = url.path
        }
    }
}
