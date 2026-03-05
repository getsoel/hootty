import AppKit
import SwiftUI
import HoottyCore

struct PaneTitleBar: View {
    let pane: Pane
    let isFocused: Bool
    let theme: TerminalTheme
    let onSave: () -> Void

    @State private var isRenaming = false
    @State private var editingName = ""

    private var abbreviatedDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if pane.workingDirectory == home {
            return "~"
        } else if pane.workingDirectory.hasPrefix(home + "/") {
            return "~" + pane.workingDirectory.dropFirst(home.count)
        }
        return pane.workingDirectory
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(pane.displayName)
                .lineLimit(1)
            Spacer()
            Text(abbreviatedDirectory)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11))
        .foregroundStyle(isFocused ? Color(theme.foreground).opacity(0.8) : Color(theme.sidebarTextSecondary))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color(theme.sidebarSurface).opacity(isFocused ? 1 : 0.7))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(theme.sidebarSurface))
                .frame(height: 1)
        }
        .contextMenu {
            Button("Rename Pane") {
                editingName = pane.displayName
                isRenaming = true
            }
            if pane.customName != nil {
                Button("Reset Name") {
                    pane.customName = nil
                    onSave()
                }
            }
        }
        .alert("Rename Pane", isPresented: $isRenaming) {
            TextField("Pane name", text: $editingName)
            Button("OK") {
                let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    pane.customName = trimmed
                    onSave()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct SplitNodeView: View {
    @Bindable var node: SplitNode
    let focusedPaneID: UUID?
    let theme: TerminalTheme
    let isInSplit: Bool
    let onFocusPane: (UUID) -> Void
    let onSave: () -> Void

    var body: some View {
        switch node.content {
        case .leaf(let pane):
            let isFocused = pane.id == focusedPaneID
            VStack(spacing: 0) {
                PaneTitleBar(pane: pane, isFocused: isFocused, theme: theme, onSave: onSave)

                TerminalPaneView(pane: pane, isFocused: isFocused)
                    .onTapGesture {
                        onFocusPane(pane.id)
                    }
            }
            .overlay {
                if !isFocused && isInSplit {
                    Color.black.opacity(0.3)
                        .allowsHitTesting(false)
                }
            }

        case .split(let direction, let first, let second):
            splitContent(direction: direction, first: first, second: second)
        }
    }

    @GestureState private var splitDragDelta: CGFloat = 0

    private func splitContent(direction: SplitDirection, first: SplitNode, second: SplitNode) -> some View {
        GeometryReader { geometry in
            let isH = direction == .horizontal
            let totalSize = isH ? geometry.size.width : geometry.size.height
            let dividerThickness: CGFloat = 2
            let usableSize = totalSize - dividerThickness
            let effectiveRatio = usableSize > 0
                ? min(max(node.splitRatio + splitDragDelta / usableSize, 0.1), 0.9)
                : node.splitRatio
            let firstSize = usableSize * effectiveRatio
            let secondSize = usableSize - firstSize
            let dividerPos = firstSize
            let secondPos = firstSize + dividerThickness

            ZStack(alignment: .topLeading) {
                // First pane
                SplitNodeView(node: first, focusedPaneID: focusedPaneID, theme: theme, isInSplit: true, onFocusPane: onFocusPane, onSave: onSave)
                    .frame(
                        width: isH ? firstSize : geometry.size.width,
                        height: isH ? geometry.size.height : firstSize
                    )

                // Visible divider line
                Rectangle()
                    .fill(Color(theme.palette[0]))
                    .frame(
                        width: isH ? dividerThickness : geometry.size.width,
                        height: isH ? geometry.size.height : dividerThickness
                    )
                    .offset(
                        x: isH ? dividerPos : 0,
                        y: isH ? 0 : dividerPos
                    )

                // Invisible wide drag handle
                Color.clear
                    .frame(
                        width: isH ? 8 : geometry.size.width,
                        height: isH ? geometry.size.height : 8
                    )
                    .contentShape(Rectangle())
                    .offset(
                        x: isH ? dividerPos - 3 : 0,
                        y: isH ? 0 : dividerPos - 3
                    )
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .updating($splitDragDelta) { value, state, _ in
                                state = isH ? value.translation.width : value.translation.height
                            }
                            .onEnded { value in
                                let delta = isH ? value.translation.width : value.translation.height
                                guard usableSize > 0 else { return }
                                node.splitRatio = min(max(node.splitRatio + delta / usableSize, 0.1), 0.9)
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            if isH {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.resizeUpDown.push()
                            }
                        } else {
                            NSCursor.pop()
                        }
                    }

                // Second pane
                SplitNodeView(node: second, focusedPaneID: focusedPaneID, theme: theme, isInSplit: true, onFocusPane: onFocusPane, onSave: onSave)
                    .frame(
                        width: isH ? secondSize : geometry.size.width,
                        height: isH ? geometry.size.height : secondSize
                    )
                    .offset(
                        x: isH ? secondPos : 0,
                        y: isH ? 0 : secondPos
                    )
            }
        }
    }
}
