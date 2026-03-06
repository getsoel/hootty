import AppKit
import SwiftUI
import HoottyCore

struct SplitNodeView: View {
    @Bindable var node: SplitNode
    let focusedPaneGroupID: UUID?
    let tokens: DesignTokens
    let isInSplit: Bool
    let onFocusPaneGroup: (UUID) -> Void
    let onAddPane: (UUID) -> Void
    let onRemovePane: (UUID) -> Void
    var onSplitPane: ((SplitDirection) -> Void)?
    let onSave: () -> Void

    var body: some View {
        switch node.content {
        case .leaf(let group):
            PaneGroupView(
                group: group,
                isFocused: group.id == focusedPaneGroupID,
                tokens: tokens,
                onFocusPaneGroup: onFocusPaneGroup,
                onAddPane: { onAddPane(group.id) },
                onRemovePane: onRemovePane,
                onSplitPane: onSplitPane,
                onSave: onSave
            )

        case .split(let direction, let first, let second):
            splitContent(direction: direction, first: first, second: second)
        }
    }

    @GestureState private var splitDragDelta: CGFloat = 0

    private func splitContent(direction: SplitDirection, first: SplitNode, second: SplitNode) -> some View {
        GeometryReader { geometry in
            let isH = direction == .horizontal
            let totalSize = isH ? geometry.size.width : geometry.size.height
            let dividerThickness: CGFloat = 1
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
                SplitNodeView(node: first, focusedPaneGroupID: focusedPaneGroupID, tokens: tokens, isInSplit: true, onFocusPaneGroup: onFocusPaneGroup, onAddPane: onAddPane, onRemovePane: onRemovePane, onSplitPane: onSplitPane, onSave: onSave)
                    .frame(
                        width: isH ? firstSize : geometry.size.width,
                        height: isH ? geometry.size.height : firstSize
                    )

                // Visible divider line
                Rectangle()
                    .fill(Color(tokens.border))
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
                        width: isH ? 16 : geometry.size.width,
                        height: isH ? geometry.size.height : 16
                    )
                    .contentShape(Rectangle())
                    .offset(
                        x: isH ? dividerPos - 7.5 : 0,
                        y: isH ? 0 : dividerPos - 7.5
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
                SplitNodeView(node: second, focusedPaneGroupID: focusedPaneGroupID, tokens: tokens, isInSplit: true, onFocusPaneGroup: onFocusPaneGroup, onAddPane: onAddPane, onRemovePane: onRemovePane, onSplitPane: onSplitPane, onSave: onSave)
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
