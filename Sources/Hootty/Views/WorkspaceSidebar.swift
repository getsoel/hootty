import SwiftUI
import UniformTypeIdentifiers
import HoottyCore

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let tokens: DesignTokens
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onMoveWorkspace: (UUID, Int) -> Void
    var onSelectPane: (UUID, UUID) -> Void
    var onRemovePane: (UUID, UUID) -> Void
    var onNewWorktree: ((UUID) -> Void)?
    var onSave: (() -> Void)?
    @Binding var sidebarHasFocus: Bool
    var sidebarWidth: CGFloat

    @FocusState private var isFocused: Bool
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
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { navigatePrevious(); return .handled }
        .onKeyPress(.downArrow) { navigateNext(); return .handled }
        .onKeyPress(.return) { sidebarHasFocus = false; return .handled }
        .onKeyPress(.escape) { sidebarHasFocus = false; return .handled }
        .onChange(of: sidebarHasFocus) { _, hasFocus in isFocused = hasFocus }
        .onChange(of: isFocused) { _, focused in
            if !focused && sidebarHasFocus { sidebarHasFocus = false }
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
                    let canClose = workspace.allPanes.count > 1
                    let layoutRects = canClose ? workspace.rootNode.paneRects() : [:]

                    workspaceRow(workspace)

                    ForEach(workspace.allPanes) { pane in
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

    private var addWorkspaceButton: some View {
        Button(action: onAddWorkspace) {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: TypeScale.smallSize))
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

    // MARK: - Keyboard Navigation

    private var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    private func navigateNext() {
        guard let ws = selectedWorkspace else { return }
        let panes = ws.allPanes
        guard let id = ws.focusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == id }),
              idx + 1 < panes.count else { return }
        onSelectPane(ws.id, panes[idx + 1].id)
    }

    private func navigatePrevious() {
        guard let ws = selectedWorkspace else { return }
        let panes = ws.allPanes
        guard let id = ws.focusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == id }),
              idx > 0 else { return }
        onSelectPane(ws.id, panes[idx - 1].id)
    }

    // MARK: - Workspace row (depth 0, no tree lines)

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isHovered = workspace.id == hoveredWorkspaceID
        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: TypeScale.iconSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 16)

            Text(workspace.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            Rectangle()
                .fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredWorkspaceID = workspace.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredWorkspaceID = nil
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedWorkspaceID = workspace.id
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
            Button("Close Workspace") {
                onRemoveWorkspace(workspace.id)
            }
        }
    }

    // MARK: - Pane row

    private func paneRow(_ pane: Pane, workspace: Workspace, canClose: Bool, layoutRects: [UUID: CGRect]) -> some View {
        let isFocusedPane = workspace.focusedPaneID == pane.id && workspace.id == selectedWorkspaceID
        let isHovered = pane.id == hoveredPaneID
        let isConnected = pane.branch != nil

        return HStack(spacing: 0) {
            TreeConnectorView(depth: 1, tokens: tokens)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    StatusDotView(attentionKind: pane.attentionKind, isThinking: pane.isThinking, tokens: tokens)
                        .fixedSize()
                        .frame(width: 16)

                    Text(pane.displayName)
                        .font(.system(size: TypeScale.bodySize))
                        .foregroundStyle(Color(tokens.textMuted))
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
                .padding(.vertical, Spacing.md)

                if isConnected {
                    HStack(spacing: 6) {
                        Canvas { context, size in
                            let lineColor = Color(tokens.textMuted)
                                .opacity(0.3)
                            let midX = size.width / 2
                            let midY = size.height / 2
                            var path = Path()
                            path.move(to: CGPoint(x: midX, y: 0))
                            path.addLine(to: CGPoint(x: midX, y: midY))
                            path.addLine(to: CGPoint(x: size.width, y: midY))
                            context.stroke(path, with: .color(lineColor), lineWidth: 1)
                        }
                        .frame(width: 16)
                        .frame(maxHeight: .infinity)

                        connectedDetailLine(pane: pane)
                    }
                    .padding(.bottom, Spacing.md)
                }
            }
            .padding(.trailing, Spacing.md)
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
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredPaneID = pane.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredPaneID = nil
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            sidebarHasFocus = true
            onSelectPane(workspace.id, pane.id)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(pane.displayName)
        .contextMenu {
            Button("Rename Pane") {
                editingPaneName = pane.displayName
                renamePaneTargetID = pane.id
            }
            if isConnected {
                Button("New Worktree") {
                    onNewWorktree?(workspace.id)
                }
            }
            if canClose {
                Button("Close Pane") {
                    onRemovePane(workspace.id, pane.id)
                }
            }
        }
    }

    // MARK: - Connected Detail Line

    private func connectedDetailLine(pane: Pane) -> some View {
        let branchColor = Color(tokens.textAccent)
        let mutedColor = Color(tokens.textMuted)

        var combined = Text(pane.branch ?? "")
            .foregroundColor(branchColor)

        if pane.worktreePath != nil {
            combined = combined + Text(" (worktree)").foregroundColor(mutedColor)
        }

        return combined
            .font(.system(size: TypeScale.bodySize))
            .lineLimit(1)
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
    let tokens: DesignTokens

    private let gutterWidth: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let lineColor = Color(tokens.textMuted).opacity(0.3)
            let x = size.width - gutterWidth / 2
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(lineColor), lineWidth: 1)
        }
        .frame(width: CGFloat(depth) * gutterWidth)
    }
}

