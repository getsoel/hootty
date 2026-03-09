import SwiftUI
import HoottyCore

struct SplitNodeView: View {
    @Bindable var node: SplitNode
    let focusedPaneID: UUID?
    let tokens: DesignTokens
    let isInSplit: Bool
    let onFocusPane: (UUID) -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
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
                SplitNodeView(node: first, focusedPaneID: focusedPaneID, tokens: tokens, isInSplit: true, onFocusPane: onFocusPane, onSplitPane: onSplitPane, onSave: onSave)
                    .frame(
                        width: isH ? firstSize : geometry.size.width,
                        height: isH ? geometry.size.height : firstSize
                    )

                // Second pane
                SplitNodeView(node: second, focusedPaneID: focusedPaneID, tokens: tokens, isInSplit: true, onFocusPane: onFocusPane, onSplitPane: onSplitPane, onSave: onSave)
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
                    .overlay(ResizeCursorView(isHorizontal: isH))
            }
        }
    }
}

// MARK: - Resize Cursor NSView

private struct ResizeCursorView: NSViewRepresentable {
    let isHorizontal: Bool

    func makeNSView(context: Context) -> _ResizeCursorNSView {
        _ResizeCursorNSView(isHorizontal: isHorizontal)
    }

    func updateNSView(_ nsView: _ResizeCursorNSView, context: Context) {
        nsView.isHorizontal = isHorizontal
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

final class _ResizeCursorNSView: NSView {
    var isHorizontal: Bool
    private var trackingArea: NSTrackingArea?

    init(isHorizontal: Bool) {
        self.isHorizontal = isHorizontal
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeInActiveApp, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        let cursor: NSCursor = isHorizontal ? .resizeLeftRight : .resizeUpDown
        cursor.set()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
