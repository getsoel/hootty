import HoottyCore
import SwiftUI

struct WorkspaceRow: View {
    let workspace: Workspace
    let isSelected: Bool
    let isCollapsed: Bool
    let isCursorTarget: Bool
    let tokens: DesignTokens
    var isPinned: Bool = false
    var onSelect: () -> Void
    var onRename: (UUID, String) -> Void
    var onRemove: (UUID) -> Void
    var onToggleCollapse: () -> Void
    var onTogglePinWorkspace: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isPinned ? "pin.fill" : (isCollapsed ? "folder" : "folder.fill"))
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .frame(width: TreeLayout.columnWidth)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onToggleCollapse()
                    }
                }

            Text(workspace.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .background(
            Rectangle()
                .fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .overlay {
            if isCursorTarget {
                Rectangle()
                    .stroke(Color(tokens.borderFocused), lineWidth: 1)
            }
        }
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
        .draggable(workspace.id.uuidString)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(workspace.name)
        .contextMenu {
            Button("Rename Workspace") {
                onRename(workspace.id, workspace.name)
            }
            Button(isPinned ? "Unpin Workspace" : "Pin Workspace") {
                onTogglePinWorkspace?()
            }
            Button(isCollapsed ? "Expand" : "Collapse") {
                onToggleCollapse()
            }
            Button("Close Workspace") {
                onRemove(workspace.id)
            }
        }
    }
}
