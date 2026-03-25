import SwiftUI

// MARK: - TODOリストの1行

struct TodoRowView: View {
    let item: TodoItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppLayout.paddingSmall) {
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textTertiary)

            Text(item.text)
                .font(AppTypography.label)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, AppLayout.paddingLarge)
        .padding(.vertical, 7)
        .background(
            isSelected
                ? AppColors.surfaceSelected
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(AppColors.accent)
                    .frame(width: 2)
            }
        }
    }
}
