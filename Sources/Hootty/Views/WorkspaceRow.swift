import HoottyCore
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceRow: View {
    let workspace: Workspace
    let isSelected: Bool
    let tokens: DesignTokens
    var onSelect: () -> Void
    var onRename: (UUID, String) -> Void
    var onRemove: (UUID) -> Void
    var onMove: (UUID, VerticalEdge?) -> Void
    @Binding var dropTargetWorkspaceID: UUID?
    @Binding var dropEdge: VerticalEdge?
    @Binding var workspaceRowHeight: CGFloat

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: TreeLayout.columnWidth)

            Text(workspace.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .background(
            Rectangle()
                .fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if dropTargetWorkspaceID != nil {
                    dropTargetWorkspaceID = nil
                    dropEdge = nil
                }
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
        .overlay(alignment: dropEdge == .top ? .top : .bottom) {
            if dropTargetWorkspaceID == workspace.id, let edge = dropEdge {
                Rectangle()
                    .fill(Color(tokens.textAccent))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: edge == .top ? -1 : 1)
            }
        }
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.size.height, initial: true) { _, h in
                workspaceRowHeight = h
            }
        })
        .draggable(workspace.id.uuidString)
        .onDrop(of: [.utf8PlainText], delegate: WorkspaceRowDropDelegate(
            workspaceID: workspace.id,
            onMove: onMove,
            dropTargetWorkspaceID: $dropTargetWorkspaceID,
            dropEdge: $dropEdge,
            rowHeight: workspaceRowHeight
        ))
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(workspace.name)
        .contextMenu {
            Button("Rename Workspace") {
                onRename(workspace.id, workspace.name)
            }
            Button("Close Workspace") {
                onRemove(workspace.id)
            }
        }
    }
}

// MARK: - Workspace Drag-and-Drop

private struct WorkspaceRowDropDelegate: DropDelegate {
    let workspaceID: UUID
    let onMove: (UUID, VerticalEdge?) -> Void
    @Binding var dropTargetWorkspaceID: UUID?
    @Binding var dropEdge: VerticalEdge?
    let rowHeight: CGFloat

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.utf8PlainText])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let newEdge: VerticalEdge = info.location.y < rowHeight / 2 ? .top : .bottom
        if dropEdge != newEdge || dropTargetWorkspaceID != workspaceID {
            dropEdge = newEdge
            dropTargetWorkspaceID = workspaceID
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.utf8PlainText]).first else { return false }
        let capturedOnMove = onMove
        let capturedEdge = dropEdge

        provider.loadObject(ofClass: NSString.self) { [self] nsString, _ in
            guard let uuidString = nsString as? String,
                  let sourceID = UUID(uuidString: uuidString) else { return }
            DispatchQueue.main.async { [self] in
                dropTargetWorkspaceID = nil
                dropEdge = nil
                capturedOnMove(sourceID, capturedEdge)
            }
        }

        dropTargetWorkspaceID = nil
        dropEdge = nil
        return true
    }

    func dropExited(info _: DropInfo) {
        if dropTargetWorkspaceID == workspaceID {
            dropTargetWorkspaceID = nil
            dropEdge = nil
        }
    }
}
