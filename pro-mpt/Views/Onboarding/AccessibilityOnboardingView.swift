import SwiftUI

// MARK: - アクセシビリティ権限のオンボーディング画面

struct AccessibilityOnboardingView: View {
    let appState: AppState
    var onGranted: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.badge.eye")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.accent)
                .padding(.top, 8)

            Text("アクセシビリティ権限が必要です")
                .font(.system(size: 18, weight: .semibold))

            Text("pro-mptはF16キーでどこからでも起動するために、\nアクセシビリティ権限が必要です。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(appState.isAccessibilityGranted ? "権限が付与されました" : "権限の付与を待っています...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if appState.isAccessibilityGranted {
                Button("始める") {
                    onGranted?()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(AppColors.accent))
            } else {
                Button("システム設定を開く") {
                    AccessibilityManager.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(AppColors.accent))

                Text("システム設定 > プライバシーとセキュリティ > アクセシビリティ\nで pro-mpt を許可してください")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(32)
        .frame(width: 460, height: 320)
    }
}
