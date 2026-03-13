import SwiftUI
import HoottyCore

struct SplitNodeView: View {
    @Bindable var node: SplitNode
    let focusedPaneID: UUID?
    let tokens: DesignTokens
    let isInSplit: Bool
    let onFocusPane: (UUID) -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onClosePane: ((UUID) -> Void)?
    var onSwapPanes: ((UUID, UUID) -> Void)?
    var onNewWorktree: (() -> Void)?
    let onSave: () -> Void

    var body: some View {
        switch node.content {
        case .leaf(let pane):
            PaneContentView(
                pane: pane,
                isFocused: pane.id == focusedPaneID,
                tokens: tokens,
                onFocusPane: { onFocusPane(pane.id) },
                onSplitPane: onSplitPane,
                onClosePane: onClosePane,
                onSwapPanes: onSwapPanes,
                onNewWorktree: onNewWorktree,
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
                SplitNodeView(node: first, focusedPaneID: focusedPaneID, tokens: tokens, isInSplit: true, onFocusPane: onFocusPane, onSplitPane: onSplitPane, onClosePane: onClosePane, onSwapPanes: onSwapPanes, onNewWorktree: onNewWorktree, onSave: onSave)
                    .frame(
                        width: isH ? firstSize : geometry.size.width,
                        height: isH ? geometry.size.height : firstSize
                    )

                // Second pane
                SplitNodeView(node: second, focusedPaneID: focusedPaneID, tokens: tokens, isInSplit: true, onFocusPane: onFocusPane, onSplitPane: onSplitPane, onClosePane: onClosePane, onSwapPanes: onSwapPanes, onNewWorktree: onNewWorktree, onSave: onSave)
                    .frame(
                        width: isH ? secondSize : geometry.size.width,
                        height: isH ? geometry.size.height : secondSize
                    )
                    .offset(
                        x: isH ? secondPos : 0,
                        y: isH ? 0 : secondPos
                    )

                // Visible divider line (on top of panes)
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
                    .allowsHitTesting(false)

                // Invisible wide drag handle (on top of everything)
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
                    .onContinuousHover { phase in
                        switch phase {
                        case .active:
                            DispatchQueue.main.async {
                                (isH ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set()
                            }
                        case .ended:
                            DispatchQueue.main.async {
                                NSCursor.arrow.set()
                            }
                        }
                    }
            }
        }
    }
}
