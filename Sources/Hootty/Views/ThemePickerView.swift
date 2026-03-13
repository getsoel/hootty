import SwiftUI
import HoottyCore

struct ThemePickerView: View {
    let tokens: DesignTokens
    let themePreviews: [ThemePreview]
    let selectedThemeName: String
    let onSelectTheme: (String) -> Void
    let onPreview: (String) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var scrollToSelection = false
    @State private var suppressHover = false
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredThemes: [ThemePreview] {
        if query.isEmpty { return themePreviews }
        return themePreviews.filter { $0.name.localizedCaseInsensitiveContains(query) }
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
            .frame(width: 500)
            .frame(maxHeight: 460)
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
            // Resign the terminal NSView's first responder so SwiftUI can claim focus
            NSApp.keyWindow?.makeFirstResponder(nil)
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
            // Scroll to currently selected theme
            if let idx = filteredThemes.firstIndex(where: { $0.name == selectedThemeName }) {
                selectedIndex = idx
                scrollToSelection = true
            }
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                suppressHover = true
                selectedIndex -= 1
                scrollToSelection = true
                previewCurrentSelection()
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredThemes.count - 1 {
                suppressHover = true
                selectedIndex += 1
                scrollToSelection = true
                previewCurrentSelection()
            }
            return .handled
        }
        .onKeyPress(.return) {
            confirmSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var searchField: some View {
        TextField("Search themes...", text: $query)
            .textFieldStyle(.plain)
            .font(.system(size: TypeScale.bodySize))
            .foregroundColor(Color(tokens.text))
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
                    let themes = filteredThemes
                    let pinnedCount = themes.prefix(while: { $0.name.hasPrefix("Catppuccin") }).count
                    let showSections = pinnedCount > 0 && pinnedCount < themes.count

                    if showSections {
                        sectionHeader("Recommended")
                    }
                    ForEach(Array(themes.enumerated()), id: \.element.id) { index, preview in
                        if showSections && index == pinnedCount {
                            sectionHeader("All Themes")
                        }
                        themeRow(preview, isSelected: index == selectedIndex)
                            .id(preview.name)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                confirmSelection()
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active:
                                    if !suppressHover {
                                        selectedIndex = index
                                    }
                                case .ended:
                                    suppressHover = false
                                }
                            }
                    }
                }
            }
            .onChange(of: selectedIndex) {
                if scrollToSelection, let theme = filteredThemes[safe: selectedIndex] {
                    proxy.scrollTo(theme.name, anchor: .center)
                    scrollToSelection = false
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: TypeScale.captionSize, weight: .semibold))
            .foregroundStyle(Color(tokens.textMuted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
    }

    private func themeRow(_ preview: ThemePreview, isSelected: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            // Color swatch strip: bg + 6 representative ANSI colors
            HStack(spacing: Spacing.xs) {
                colorSwatch(preview.background)
                colorSwatch(preview.palette[1])  // red
                colorSwatch(preview.palette[2])  // green
                colorSwatch(preview.palette[3])  // yellow
                colorSwatch(preview.palette[4])  // blue
                colorSwatch(preview.palette[5])  // pink
                colorSwatch(preview.palette[6])  // cyan
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

    private func previewCurrentSelection() {
        guard let theme = filteredThemes[safe: selectedIndex] else { return }
        onPreview(theme.name)
    }

    private func confirmSelection() {
        guard let theme = filteredThemes[safe: selectedIndex] else { return }
        onSelectTheme(theme.name)
    }
}