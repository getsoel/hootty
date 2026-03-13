import SwiftUI
import HoottyCore

struct BranchPickerView: View {
    let tokens: DesignTokens
    let branches: [BranchRef]
    let onSelectBranch: (String) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var scrollToSelection = false
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredBranches: [BranchRef] {
        if query.isEmpty { return branches }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            Color(tokens.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

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
            NSApp.keyWindow?.makeFirstResponder(nil)
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
            if selectedIndex < filteredBranches.count - 1 {
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
        TextField("Search branches...", text: $query)
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
                    ForEach(Array(filteredBranches.enumerated()), id: \.element.id) { index, branch in
                        branchRow(branch, isSelected: index == selectedIndex)
                            .id(branch.id)
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
                if scrollToSelection, let branch = filteredBranches[safe: selectedIndex] {
                    proxy.scrollTo(branch.id, anchor: .center)
                    scrollToSelection = false
                }
            }
        }
    }

    private func branchRow(_ branch: BranchRef, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: branch.hasPanes ? "cube.fill" : "cube")
                .font(.system(size: TypeScale.iconSize))
                .foregroundStyle(Color(isSelected ? tokens.elementSelectedText : tokens.textMuted))

            Text(branch.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.elementSelectedText : tokens.text))

            if branch.isHead {
                Text("HEAD")
                    .font(.system(size: TypeScale.smallSize, weight: .medium))
                    .foregroundStyle(Color(isSelected ? tokens.elementSelectedText.withAlphaComponent(0.7) : tokens.textAccent))
            }

            Spacer()

            if branch.hasPanes {
                Text("\(branch.paneIDs.count) pane\(branch.paneIDs.count == 1 ? "" : "s")")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(isSelected ? tokens.elementSelectedText.withAlphaComponent(0.7) : tokens.textMuted))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + Spacing.xs)
        .background(isSelected ? Color(tokens.elementSelected) : Color.clear)
    }

    private func executeSelected() {
        guard let branch = filteredBranches[safe: selectedIndex] else { return }
        onDismiss()
        onSelectBranch(branch.name)
    }
}
