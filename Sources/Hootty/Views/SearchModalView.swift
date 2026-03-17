import HoottyCore
import SwiftUI

/// Generic search modal container used by CommandPaletteView and ThemePickerView.
/// Provides scrim backdrop, search field, keyboard navigation, scroll-to-selection,
/// and hover management. Consumers provide row content and action callbacks.
struct SearchModalView<Item: Identifiable, RowContent: View>: View where Item.ID: Hashable {
    let tokens: DesignTokens
    let panelWidth: CGFloat
    let panelMaxHeight: CGFloat
    let placeholder: String
    let allItems: [Item]
    let filter: (Item, String) -> Bool
    var initialSelectedIndex: Int?
    var onArrowNav: ((Item) -> Void)?
    let onSelect: (Item) -> Void
    let onDismiss: () -> Void
    var sectionHeader: ((Int, [Item]) -> String?)?
    @ViewBuilder var rowContent: (Item, Bool) -> RowContent

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var scrollToSelection = false
    @State private var suppressHover = false
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredItems: [Item] {
        if query.isEmpty { return allItems }
        return allItems.filter { filter($0, query) }
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
            .frame(width: panelWidth)
            .frame(maxHeight: panelMaxHeight)
            .background(Color(tokens.surface))
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusLg)
                    .strokeBorder(Color(tokens.border), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
        }
        .onAppear {
            NSApp.keyWindow?.makeFirstResponder(nil)
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
            if let idx = initialSelectedIndex {
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
                if let item = filteredItems[safe: selectedIndex] {
                    onArrowNav?(item)
                }
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredItems.count - 1 {
                suppressHover = true
                selectedIndex += 1
                scrollToSelection = true
                if let item = filteredItems[safe: selectedIndex] {
                    onArrowNav?(item)
                }
            }
            return .handled
        }
        .onKeyPress(.return) {
            if let item = filteredItems[safe: selectedIndex] {
                onSelect(item)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var searchField: some View {
        TextField(placeholder, text: $query)
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
                    let items = filteredItems
                    let headers: [Int: String] = {
                        guard let sectionHeader else { return [:] }
                        var result: [Int: String] = [:]
                        for i in items.indices {
                            if let h = sectionHeader(i, items) { result[i] = h }
                        }
                        return result
                    }()
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if let header = headers[index] {
                            sectionHeaderView(header)
                        }
                        rowContent(item, index == selectedIndex)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                onSelect(item)
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
                if scrollToSelection, let item = filteredItems[safe: selectedIndex] {
                    proxy.scrollTo(item.id, anchor: .center)
                    scrollToSelection = false
                }
            }
        }
    }

    private func sectionHeaderView(_ title: String) -> some View {
        Text(title)
            .font(.system(size: TypeScale.captionSize, weight: .semibold))
            .foregroundStyle(Color(tokens.textMuted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
    }
}
