import HoottyCore
import SwiftUI

struct ThemePickerView: View {
    let tokens: DesignTokens
    let themePreviews: [ThemePreview]
    let selectedThemeName: String
    let onSelectTheme: (String) -> Void
    let onPreview: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        SearchModalView(
            tokens: tokens,
            panelWidth: 500,
            panelMaxHeight: 460,
            placeholder: "Search themes...",
            allItems: themePreviews,
            filter: { $0.name.localizedCaseInsensitiveContains($1) },
            initialSelectedIndex: themePreviews.firstIndex(where: { $0.name == selectedThemeName }),
            onArrowNav: { preview in onPreview(preview.name) },
            onSelect: { preview in onSelectTheme(preview.name) },
            onDismiss: onDismiss,
            sectionHeader: { index, items in
                let pinnedCount = items.prefix(while: { $0.name.hasPrefix("Catppuccin") }).count
                let showSections = pinnedCount > 0 && pinnedCount < items.count
                guard showSections else { return nil }
                if index == 0 { return "Recommended" }
                if index == pinnedCount { return "All Themes" }
                return nil
            },
            rowContent: { preview, isSelected in
                themeRow(preview, isSelected: isSelected)
            }
        )
    }

    private func themeRow(_ preview: ThemePreview, isSelected: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            // Color swatch strip: bg + 6 representative ANSI colors
            HStack(spacing: Spacing.xs) {
                colorSwatch(preview.background)
                colorSwatch(preview.palette[1]) // red
                colorSwatch(preview.palette[2]) // green
                colorSwatch(preview.palette[3]) // yellow
                colorSwatch(preview.palette[4]) // blue
                colorSwatch(preview.palette[5]) // pink
                colorSwatch(preview.palette[6]) // cyan
            }

            Text(preview.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.elementSelectedText : tokens.text))
                .lineLimit(1)

            Spacer()

            if preview.name == selectedThemeName {
                Image(systemName: "checkmark")
                    .font(.system(size: TypeScale.captionSize, weight: .semibold))
                    .foregroundStyle(Color(tokens.textAccent))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + Spacing.xs)
        .background(isSelected ? Color(tokens.elementSelected) : Color.clear)
    }

    private func colorSwatch(_ color: NSColor) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(color))
            .frame(width: 14, height: 14)
    }
}
