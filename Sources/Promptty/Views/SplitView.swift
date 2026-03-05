import AppKit
import SwiftUI
import PrompttyCore

struct SplitNodeView: View {
    @Bindable var node: SplitNode
    let focusedPaneID: UUID?
    let onFocusPane: (UUID) -> Void

    var body: some View {
        switch node.content {
        case .leaf(let pane):
            TerminalPaneView(pane: pane, isFocused: pane.id == focusedPaneID)
                .onTapGesture {
                    onFocusPane(pane.id)
                }

        case .split(let direction, let first, let second):
            splitContent(direction: direction, first: first, second: second)
        }
    }

    @GestureState private var splitDragDelta: CGFloat = 0

    private func splitContent(direction: SplitDirection, first: SplitNode, second: SplitNode) -> some View {
        GeometryReader { geometry in
            let totalSize = direction == .horizontal ? geometry.size.width : geometry.size.height
            let dividerThickness: CGFloat = 2
            let usableSize = totalSize - dividerThickness
            let effectiveRatio = usableSize > 0
                ? min(max(node.splitRatio + splitDragDelta / usableSize, 0.1), 0.9)
                : node.splitRatio
            let firstSize = usableSize * effectiveRatio
            let secondSize = usableSize - firstSize

            if direction == .horizontal {
                HStack(spacing: 0) {
                    SplitNodeView(node: first, focusedPaneID: focusedPaneID, onFocusPane: onFocusPane)
                        .frame(width: firstSize, height: geometry.size.height)

                    splitDivider(direction: direction, totalSize: totalSize, dividerThickness: dividerThickness)

                    SplitNodeView(node: second, focusedPaneID: focusedPaneID, onFocusPane: onFocusPane)
                        .frame(width: secondSize, height: geometry.size.height)
                }
            } else {
                VStack(spacing: 0) {
                    SplitNodeView(node: first, focusedPaneID: focusedPaneID, onFocusPane: onFocusPane)
                        .frame(width: geometry.size.width, height: firstSize)

                    splitDivider(direction: direction, totalSize: totalSize, dividerThickness: dividerThickness)

                    SplitNodeView(node: second, focusedPaneID: focusedPaneID, onFocusPane: onFocusPane)
                        .frame(width: geometry.size.width, height: secondSize)
                }
            }
        }
    }

    private func splitDivider(direction: SplitDirection, totalSize: CGFloat, dividerThickness: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(
                width: direction == .horizontal ? dividerThickness : nil,
                height: direction == .vertical ? dividerThickness : nil
            )
            .overlay(
                Color.clear
                    .frame(
                        width: direction == .horizontal ? 8 : nil,
                        height: direction == .vertical ? 8 : nil
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .updating($splitDragDelta) { value, state, _ in
                                state = direction == .horizontal ? value.translation.width : value.translation.height
                            }
                            .onEnded { value in
                                let delta = direction == .horizontal ? value.translation.width : value.translation.height
                                let usableSize = totalSize - dividerThickness
                                guard usableSize > 0 else { return }
                                node.splitRatio = min(max(node.splitRatio + delta / usableSize, 0.1), 0.9)
                            }
                    )
            )
            .onHover { hovering in
                if hovering {
                    if direction == .horizontal {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.resizeUpDown.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
    }
}
