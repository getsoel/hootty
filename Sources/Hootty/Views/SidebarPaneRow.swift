import HoottyCore
import SwiftUI

struct SidebarPaneRow: View {
    let pane: Pane
    let isFocusedPane: Bool
    let isCursorTarget: Bool
    let canClose: Bool
    let layoutRects: [UUID: CGRect]
    let depth: Int
    let tokens: DesignTokens
    var onSelect: () -> Void
    var onRename: (UUID, String) -> Void
    var onClose: (UUID) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            StatusDotView(attentionKind: pane.attentionKind, isThinking: pane.isThinking, isClaudeSession: pane.claudeSessionID != nil, tokens: tokens)
                .frame(width: TreeLayout.columnWidth)

            Text(pane.flagNote ?? pane.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(pane.isFlagged && !isFocusedPane ? tokens.statusFlag : isFocusedPane ? tokens.text : tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)

            if !layoutRects.isEmpty {
                SplitLayoutThumbnail(
                    layoutRects: layoutRects,
                    highlightedPaneID: pane.id,
                    tokens: tokens
                )
            }
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + CGFloat(depth) * TreeLayout.columnWidth)
        .background(
            Rectangle()
                .fill(
                    isFocusedPane
                        ? Color(tokens.elementSelected)
                        : isHovered
                        ? Color(tokens.elementHover)
                        : pane.attentionKind != nil
                        ? Color(tokens.attentionColor(for: pane.attentionKind!)).opacity(0.12)
                        : Color.clear
                )
        )
        .overlay {
            if isCursorTarget {
                Rectangle()
                    .strokeBorder(Color(tokens.borderFocused), lineWidth: 1)
            }
        }
        .background(TreeLinesBackground(depth: depth, tokens: tokens))
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                isHovered = false
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(pane.displayName)
        .contextMenu {
            Button("Rename Pane") {
                onRename(pane.id, pane.displayName)
            }
            if canClose {
                Button("Close Pane") {
                    onClose(pane.id)
                }
            }
        }
    }
}
