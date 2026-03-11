import SwiftUI
import HoottyCore

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

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var scrollToSelection = false
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredCommands: [PaletteCommand] {
        if query.isEmpty { return commands }
        return commands.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            // Dimming backdrop
            Color(tokens.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // Floating panel
            VStack(spacing: 0) {
                searchField
                divider
                resultsList
            }
            .frame(width: 400)
            .frame(maxHeight: 300)
            .background(Color(tokens.surface))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(tokens.border), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
        }
        .onAppear {
            isSearchFieldFocused = true
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                scrollToSelection = true
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                scrollToSelection = true
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var searchField: some View {
        TextField("Search commands...", text: $query)
            .textFieldStyle(.plain)
            .font(.system(size: TypeScale.bodySize))
            .foregroundStyle(Color(tokens.text))
            .padding(Spacing.md)
            .focused($isSearchFieldFocused)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(tokens.border))
            .frame(height: 1)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        commandRow(command, isSelected: index == selectedIndex)
                            .id(command.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                executeSelected()
                            }
                            .onContinuousHover { phase in
                                if case .active = phase {
                                    selectedIndex = index
                                }
                            }
                    }
                }
            }
            .onChange(of: selectedIndex) {
                if scrollToSelection, let cmd = filteredCommands[safe: selectedIndex] {
                    proxy.scrollTo(cmd.id, anchor: .center)
                    scrollToSelection = false
                }
            }
        }
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

    private func executeSelected() {
        guard let command = filteredCommands[safe: selectedIndex] else { return }
        onDismiss()
        command.action()
    }
}