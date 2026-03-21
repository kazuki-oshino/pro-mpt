import SwiftUI

// MARK: - 履歴リストの1行

struct PromptRowView: View {
    let result: FTSSearchResult
    let isSelected: Bool
    let searchQuery: String

    var body: some View {
        HStack(spacing: AppLayout.paddingSmall) {
            // お気に入りアイコン
            if result.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.favorite)
            }

            // タイトル (マッチハイライト付き)
            highlightedTitle
                .lineLimit(1)

            Spacer(minLength: 8)

            // メタデータ
            HStack(spacing: 6) {
                if result.useCount > 1 {
                    Text("×\(result.useCount)")
                        .font(AppTypography.metadata)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Text(result.lastUsedAt.relativeDescription)
                    .font(AppTypography.metadata)
                    .foregroundStyle(AppColors.textTertiary)
            }
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

    // MARK: - マッチハイライト

    private var highlightedTitle: some View {
        if searchQuery.isEmpty {
            return Text(result.title)
                .font(AppTypography.label)
                .foregroundStyle(AppColors.textPrimary)
        }

        let title = result.title
        let query = searchQuery.lowercased()
        var attributedString = AttributedString(title)

        // クエリに含まれる各単語をハイライト
        let words = query.split(separator: " ").map(String.init)
        for word in words {
            var searchRange = attributedString.startIndex..<attributedString.endIndex
            while let range = attributedString[searchRange].range(
                of: word,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                attributedString[range].foregroundColor = NSColor(AppColors.accent)
                attributedString[range].font = .systemFont(ofSize: 13, weight: .semibold)
                if range.upperBound < searchRange.upperBound {
                    searchRange = range.upperBound..<searchRange.upperBound
                } else {
                    break
                }
            }
        }

        return Text(attributedString)
            .font(AppTypography.label)
            .foregroundStyle(AppColors.textPrimary)
    }
}

// MARK: - ショートカットヒント表示

struct ShortcutHintView: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(AppTypography.metadataMono)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(action)
                .font(AppTypography.metadata)
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}
