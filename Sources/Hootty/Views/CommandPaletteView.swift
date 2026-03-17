import HoottyCore
import SwiftUI

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let shortcut: String?
    let action: () -> Void
}

struct CommandPaletteView: View {
    let tokens: DesignTokens
    let commands: [PaletteCommand]
    let onDismiss: () -> Void

    var body: some View {
        SearchModalView(
            tokens: tokens,
            panelWidth: 400,
            panelMaxHeight: 300,
            placeholder: "Search commands...",
            allItems: commands,
            filter: { $0.title.localizedCaseInsensitiveContains($1) },
            onSelect: { command in
                onDismiss()
                command.action()
            },
            onDismiss: onDismiss,
            rowContent: { command, isSelected in
                commandRow(command, isSelected: isSelected)
            }
        )
    }

    private func commandRow(_ command: PaletteCommand, isSelected: Bool) -> some View {
        HStack {
            Text(command.title)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.elementSelectedText : tokens.text))
            Spacer()
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(isSelected ? tokens.elementSelectedText.withAlphaComponent(0.7) : tokens.textMuted))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + Spacing.xs)
        .background(isSelected ? Color(tokens.elementSelected) : Color.clear)
    }
}
