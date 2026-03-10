import SwiftUI
import UniformTypeIdentifiers
import HoottyCore
import LucideIcons

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let tokens: DesignTokens
    let flavor: CatppuccinFlavor
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onMoveWorkspace: (UUID, Int) -> Void
    var onSelectPane: (UUID, UUID) -> Void
    var onRemovePane: (UUID, UUID) -> Void
    var onSave: (() -> Void)?
    var sidebarWidth: CGFloat

    @State private var expandedWorkspaceIDs: Set<UUID> = []
    @State private var hoveredWorkspaceID: UUID?
    @State private var hoveredPaneID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renamePaneTargetID: UUID?
    @State private var editingPaneName: String = ""
    @State private var dropTargetWorkspaceID: UUID?
    @State private var dropEdge: VerticalEdge?
    @State private var workspaceRowHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            workspaceList

            Spacer(minLength: 0)

            // Divider
            Rectangle()
                .fill(Color(tokens.border))
                .frame(height: 1)

            addWorkspaceButton
        }
        .frame(width: sidebarWidth)
        .background(Color(tokens.surfaceLow))
        .onAppear {
            if let id = selectedWorkspaceID {
                expandedWorkspaceIDs.insert(id)
            }
        }
        .onChange(of: selectedWorkspaceID) { _, newID in
            if let id = newID {
                expandedWorkspaceIDs.insert(id)
            }
        }
        .alert("Rename Workspace", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Workspace name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Rename Pane", isPresented: Binding(
            get: { renamePaneTargetID != nil },
            set: { if !$0 { renamePaneTargetID = nil } }
        )) {
            TextField("Pane name", text: $editingPaneName)
            Button("OK") { commitPaneRename() }
            Button("Cancel", role: .cancel) { renamePaneTargetID = nil }
        }
    }

    private var workspaceList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(workspaces) { workspace in
                    workspaceRow(workspace)

                    if expandedWorkspaceIDs.contains(workspace.id) {
                        let panes = workspace.allPanes
                        let canClose = panes.count > 1
                        let layoutRects = canClose ? workspace.rootNode.paneRects() : [:]
                        ForEach(panes) { pane in
                            paneRow(
                                pane,
                                workspace: workspace,
                                canClose: canClose,
                                layoutRects: layoutRects
                            )
                        }
                    }
                }
            }
        }
    }

    private var addWorkspaceButton: some View {
        Button(action: onAddWorkspace) {
            HStack {
                LucideIcon(Lucide.plus, size: TypeScale.smallSize)
                Text("New Workspace")
                    .font(.system(size: TypeScale.smallSize))
            }
            .foregroundStyle(Color(tokens.textMuted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let target = workspaces.first(where: { $0.id == renameTargetID }) {
            target.name = trimmed
            onSave?()
        }
        renameTargetID = nil
    }

    private func commitPaneRename() {
        let trimmed = editingPaneName.trimmingCharacters(in: .whitespaces)
        if let targetID = renamePaneTargetID {
            for workspace in workspaces {
                if let pane = workspace.findPane(id: targetID) {
                    pane.customName = trimmed.isEmpty ? nil : trimmed
                    onSave?()
                    break
                }
            }
        }
        renamePaneTargetID = nil
    }

    // MARK: - Workspace row (depth 0, no tree lines)

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isSelected = workspace.id == selectedWorkspaceID
        let isHovered = workspace.id == hoveredWorkspaceID
        let isExpanded = expandedWorkspaceIDs.contains(workspace.id)
        return HStack(spacing: 6) {
            iconView(name: isExpanded ? "_root_open" : "_root", size: TypeScale.iconSize)

            Text(workspace.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                onRemoveWorkspace(workspace.id)
            } label: {
                LucideIcon(Lucide.x, size: 9)
                    .foregroundStyle(Color(tokens.textMuted))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            Rectangle()
                .fill(
                    isSelected
                        ? Color(tokens.elementSelected)
                        : isHovered
                            ? Color(tokens.elementHover)
                            : Color.clear
                )
        )
        .overlay {
            if !isExpanded, let kind = workspace.attentionKind {
                Color.clear
                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.attentionColor(for: kind)), lineWidth: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredWorkspaceID = workspace.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredWorkspaceID = nil
            }
        }
        .onTapGesture {
            selectedWorkspaceID = workspace.id
            expandedWorkspaceIDs.insert(workspace.id)
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
            onMove: { sourceID, edge in
                guard let targetIndex = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
                let insertIndex = edge == .top ? targetIndex : targetIndex + 1
                onMoveWorkspace(sourceID, insertIndex)
            },
            dropTargetWorkspaceID: $dropTargetWorkspaceID,
            dropEdge: $dropEdge,
            rowHeight: workspaceRowHeight
        ))
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(workspace.name)
        .contextMenu {
            Button("Rename Workspace") {
                editingName = workspace.name
                renameTargetID = workspace.id
            }
        }
    }

    // MARK: - Pane row (depth 1)

    private func paneRow(_ pane: Pane, workspace: Workspace, canClose: Bool, layoutRects: [UUID: CGRect]) -> some View {
        let isFocusedPane = workspace.focusedPaneID == pane.id && workspace.id == selectedWorkspaceID
        let isHovered = pane.id == hoveredPaneID

        return HStack(spacing: 0) {
            TreeConnectorView(
                depth: 1,
                continuingLevels: [],
                tokens: tokens
            )

            HStack(spacing: 6) {
                if !layoutRects.isEmpty {
                    SplitLayoutThumbnail(
                        layoutRects: layoutRects,
                        highlightedPaneID: pane.id,
                        isFocused: isFocusedPane,
                        tokens: tokens
                    )
                }

                iconView(name: "bash", size: TypeScale.iconSize)

                Text(pane.displayName)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(isFocusedPane ? tokens.text : tokens.textMuted))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    onRemovePane(workspace.id, pane.id)
                } label: {
                    LucideIcon(Lucide.x, size: 8)
                        .foregroundStyle(Color(tokens.textMuted))
                }
                .buttonStyle(.plain)
                .opacity(isHovered && canClose ? 1 : 0)
            }
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .padding(.leading, Spacing.md)
        .background(
            Rectangle()
                .fill(
                    isFocusedPane
                        ? Color(tokens.elementSelected)
                        : isHovered
                            ? Color(tokens.elementHover)
                            : Color.clear
                )
        )
        .overlay {
            if let kind = pane.attentionKind {
                Color.clear
                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.attentionColor(for: kind)), lineWidth: 1)
            } else if isFocusedPane {
                Rectangle().stroke(Color(tokens.textAccent), lineWidth: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredPaneID = pane.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredPaneID = nil
            }
        }
        .onTapGesture {
            onSelectPane(workspace.id, pane.id)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(pane.displayName)
        .contextMenu {
            Button("Rename Pane") {
                editingPaneName = pane.displayName
                renamePaneTargetID = pane.id
            }
            if canClose {
                Button("Close Pane") {
                    onRemovePane(workspace.id, pane.id)
                }
            }
        }
    }

    // MARK: - Helpers

    private func iconView(name: String, size: CGFloat) -> some View {
        CatppuccinIconView(name: name, size: size, flavor: flavor)
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
                self.dropTargetWorkspaceID = nil
                self.dropEdge = nil
                capturedOnMove(sourceID, capturedEdge)
            }
        }

        dropTargetWorkspaceID = nil
        dropEdge = nil
        return true
    }

    func dropExited(info: DropInfo) {
        if dropTargetWorkspaceID == workspaceID {
            dropTargetWorkspaceID = nil
            dropEdge = nil
        }
    }
}

// MARK: - Tree Connector

private struct TreeConnectorView: View {
    let depth: Int
    let continuingLevels: Set<Int>
    let tokens: DesignTokens

    private let gutterWidth: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let lineColor = Color(tokens.textMuted).opacity(0.3)

            // Draw continuing vertical lines for ancestor levels
            for level in continuingLevels {
                let x = CGFloat(level) * gutterWidth + gutterWidth / 2
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            }

            // Draw vertical line at current depth — always full height
            if depth > 0 {
                let x = size.width - gutterWidth / 2
                var verticalPath = Path()
                verticalPath.move(to: CGPoint(x: x, y: 0))
                verticalPath.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(verticalPath, with: .color(lineColor), lineWidth: 1)
            }
        }
        .frame(width: CGFloat(depth) * gutterWidth)
    }
}
