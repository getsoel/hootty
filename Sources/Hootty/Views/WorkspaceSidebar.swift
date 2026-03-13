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
    var onCreateWorktree: ((UUID, String, String) -> Void)?
    var onSave: (() -> Void)?
    @Binding var sidebarHasFocus: Bool
    @Binding var sidebarCursorPaneID: UUID?
    var sidebarWidth: CGFloat

    @FocusState private var isFocused: Bool
    @State private var hoveredWorkspaceID: UUID?
    @State private var hoveredPaneID: UUID?
    @State private var hoveredWorktreeAction: String?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renamePaneTargetID: UUID?
    @State private var editingPaneName: String = ""
    @State private var worktreeTarget: WorktreeCreationTarget?
    @State private var worktreeBranchName: String = ""
    @State private var dropTargetWorkspaceID: UUID?
    @State private var dropEdge: VerticalEdge?
    @State private var workspaceRowHeight: CGFloat = 32
    @State private var showWorktreeActions: Bool = true
    @State private var hoveredHeaderButton: String?

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            workspaceList

            Spacer(minLength: 0)
        }
        .frame(width: sidebarWidth)
        .background(Color(tokens.surfaceLow))
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { moveCursor(direction: -1); return .handled }
        .onKeyPress(.downArrow) { moveCursor(direction: 1); return .handled }
        .onKeyPress(.return) { confirmCursor(); return .handled }
        .onKeyPress(.escape) { sidebarHasFocus = false; return .handled }
        .onChange(of: sidebarHasFocus) { _, hasFocus in
            isFocused = hasFocus
            if hasFocus {
                sidebarCursorPaneID = selectedWorkspace?.focusedPaneID
            } else {
                sidebarCursorPaneID = nil
            }
        }
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
        .alert("New Worktree", isPresented: Binding(
            get: { worktreeTarget != nil },
            set: { if !$0 { worktreeTarget = nil } }
        )) {
            TextField("Branch name", text: $worktreeBranchName)
            Button("Create") { commitWorktreeCreation() }
            Button("Cancel", role: .cancel) { worktreeTarget = nil }
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 0) {
            Text("Workspaces")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
                .padding(.leading, Spacing.md)

            Spacer(minLength: 0)

            HStack(spacing: Spacing.xs) {
                Button {
                    showWorktreeActions.toggle()
                } label: {
                    Image(systemName: "cube")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(showWorktreeActions ? tokens.textAccent : tokens.textMuted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(RoundedRectangle(cornerRadius: 4).fill(hoveredHeaderButton == "worktree" ? Color(tokens.elementHover) : Color.clear))
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                hoveredHeaderButton = "worktree"
                                DispatchQueue.main.async { NSCursor.pointingHand.set() }
                            case .ended:
                                if hoveredHeaderButton == "worktree" { hoveredHeaderButton = nil }
                            @unknown default: break
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle worktrees")

                Button(action: onAddWorkspace) {
                    Image(systemName: "plus")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(RoundedRectangle(cornerRadius: 4).fill(hoveredHeaderButton == "add" ? Color(tokens.elementHover) : Color.clear))
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                hoveredHeaderButton = "add"
                                DispatchQueue.main.async { NSCursor.pointingHand.set() }
                            case .ended:
                                if hoveredHeaderButton == "add" { hoveredHeaderButton = nil }
                            @unknown default: break
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New workspace")
            }
            .padding(Spacing.smd)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color(tokens.border)).frame(width: 1)
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var workspaceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(workspaces) { workspace in
                    workspaceRow(workspace)
                    workspacePaneList(workspace)
                }
            }
        }
    }

    @ViewBuilder
    private func workspacePaneList(_ workspace: Workspace) -> some View {
        let canClose = workspace.allPanes.count > 1
        let layoutRects = canClose ? workspace.rootNode.paneRects() : [:]
        let hasBranches = workspace.hasBranchSections
        let depth = hasBranches ? 2 : 1

        let sections = workspace.sidebarSections
        let headBranchRepos = Set(sections.filter(\.isHead).compactMap(\.repoRoot))
        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
            if hasBranches {
                branchSectionHeader(section)
            }

            ForEach(section.panes) { pane in
                paneRow(
                    pane,
                    workspace: workspace,
                    canClose: canClose,
                    layoutRects: layoutRects,
                    depth: depth
                )
            }

            // Show "+ New worktree" at the end of each repo's group
            // (right before the next HEAD section or at the end of the list)
            if showWorktreeActions,
               let repoRoot = section.repoRoot,
               headBranchRepos.contains(repoRoot) {
                let isLastForRepo = index + 1 >= sections.count
                    || sections[index + 1].isHead
                    || sections[index + 1].repoRoot != repoRoot
                if isLastForRepo {
                    createWorktreeRow(workspace: workspace, repoRoot: repoRoot, depth: depth - 1)
                }
            }
        }
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

    private func commitWorktreeCreation() {
        let trimmed = worktreeBranchName.trimmingCharacters(in: .whitespaces)
        if let target = worktreeTarget, !trimmed.isEmpty {
            onCreateWorktree?(target.workspaceID, target.repoRoot, trimmed)
        }
        worktreeTarget = nil
        worktreeBranchName = ""
    }

    // MARK: - Keyboard Navigation

    private var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    /// Flat list of all navigable (workspace, pane) pairs across all workspaces.
    private var allNavigableItems: [(workspaceID: UUID, paneID: UUID)] {
        workspaces.flatMap { ws in
            ws.allPanes.map { (ws.id, $0.id) }
        }
    }

    private func moveCursor(direction: Int) {
        let items = allNavigableItems
        guard !items.isEmpty else { return }
        let currentID = sidebarCursorPaneID ?? selectedWorkspace?.focusedPaneID
        guard let currentID,
              let idx = items.firstIndex(where: { $0.paneID == currentID }) else {
            if let first = items.first { sidebarCursorPaneID = first.paneID }
            return
        }
        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < items.count else { return }
        sidebarCursorPaneID = items[newIdx].paneID
    }

    private func confirmCursor() {
        if let cursorID = sidebarCursorPaneID,
           let item = allNavigableItems.first(where: { $0.paneID == cursorID }) {
            onSelectPane(item.workspaceID, item.paneID)
        }
        sidebarHasFocus = false
    }

    // MARK: - Workspace row (depth 0, no tree lines)

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isHovered = workspace.id == hoveredWorkspaceID
        return HStack(spacing: 6) {
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
                // Clear stale drop state from cancelled drags
                // (onContinuousHover doesn't fire during drag sessions)
                if dropTargetWorkspaceID != nil {
                    dropTargetWorkspaceID = nil
                    dropEdge = nil
                }
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

    // MARK: - Branch Section Header

    private func branchSectionHeader(_ section: SidebarSection) -> some View {
        HStack(spacing: 6) {
            Image(systemName: worktreeIcon(for: section))
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: TreeLayout.columnWidth)

            if let displayLabel = section.displayLabel {
                let isWorktree = section.panes.contains { $0.worktreePath != nil }
                branchLabelView(displayLabel, repoDisplayName: section.repoDisplayName, isWorktree: isWorktree)
            } else {
                Text("No Branch")
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + TreeLayout.columnWidth)
        .background(TreeLinesBackground(depth: 1, tokens: tokens))
        .contextMenu {
            if !section.isHead, let branch = section.branch,
               let worktreePath = section.panes.compactMap({ $0.worktreePath }).first {
                Button("Copy merge prompt") {
                    let prompt = "Merge branch '\(branch)' into the main branch. The worktree is at \(worktreePath). Remove the worktree when done."
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prompt, forType: .string)
                }
            }
        }
    }

    private func worktreeIcon(for section: SidebarSection) -> String {
        if section.branch == nil { return "cube.transparent" }
        return section.isHead ? "cube.fill" : "cube"
    }

    @ViewBuilder
    private func branchLabelView(_ displayLabel: String, repoDisplayName: String?, isWorktree: Bool = false) -> some View {
        let treeSuffix = isWorktree
            ? Text("@").foregroundStyle(Color(tokens.textMuted).opacity(0.5)) + Text("tree").foregroundStyle(Color(tokens.textTree))
            : Text("")
        if let repoName = repoDisplayName, let slashRange = displayLabel.range(of: "/") {
            let branchPart = String(displayLabel[slashRange.upperBound...])
            (Text(repoName).foregroundStyle(Color(tokens.textRepo))
             + Text("⎇").foregroundStyle(Color(tokens.textMuted).opacity(0.5))
             + Text(branchPart).foregroundStyle(Color(tokens.textBranch))
             + treeSuffix)
                .font(.system(size: TypeScale.bodySize))
                .lineLimit(1)
        } else {
            (Text(displayLabel).foregroundStyle(Color(tokens.textBranch))
             + treeSuffix)
                .font(.system(size: TypeScale.bodySize))
                .lineLimit(1)
        }
    }

    // MARK: - Pane Row

    private func paneRow(_ pane: Pane, workspace: Workspace, canClose: Bool, layoutRects: [UUID: CGRect], depth: Int = 1) -> some View {
        let isFocusedPane = workspace.focusedPaneID == pane.id && workspace.id == selectedWorkspaceID
        let isCursorTarget = sidebarHasFocus && sidebarCursorPaneID == pane.id
        let isHovered = pane.id == hoveredPaneID

        return HStack(spacing: 6) {
            StatusDotView(attentionKind: pane.attentionKind, isThinking: pane.isThinking, tokens: tokens)
                .frame(width: TreeLayout.columnWidth)

            Text(pane.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isFocusedPane ? tokens.text : tokens.textMuted))
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
                                ? Color(tokens.statusBell).opacity(0.12)
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
                // Clear stale drop state from cancelled drags
                if dropTargetWorkspaceID != nil {
                    dropTargetWorkspaceID = nil
                    dropEdge = nil
                }
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
            if canClose {
                Button("Close Pane") {
                    onRemovePane(workspace.id, pane.id)
                }
            }
        }
    }

    // MARK: - Worktree Action Row

    private func createWorktreeRow(workspace: Workspace, repoRoot: String, depth: Int) -> some View {
        let hoverKey = "\(workspace.id)|\(repoRoot)"
        let isHovered = hoveredWorktreeAction == hoverKey
        return HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
                .frame(width: TreeLayout.columnWidth)

            Text("New worktree")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + CGFloat(depth) * TreeLayout.columnWidth)
        .background(
            Rectangle()
                .fill(isHovered ? Color(tokens.elementHover) : Color.clear)
        )
        .background(TreeLinesBackground(depth: depth, tokens: tokens))
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredWorktreeAction = hoverKey
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredWorktreeAction = nil
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            worktreeBranchName = ""
            worktreeTarget = WorktreeCreationTarget(workspaceID: workspace.id, repoRoot: repoRoot)
        }
    }
}

// MARK: - Worktree Creation Target

private struct WorktreeCreationTarget {
    let workspaceID: UUID
    let repoRoot: String
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

private enum TreeLayout {
    /// Column width shared by tree connector gutters and icon frames.
    static let columnWidth: CGFloat = 16
}

/// Draws vertical tree lines as a background, positioned within the leading padding area.
private struct TreeLinesBackground: View {
    let depth: Int
    let tokens: DesignTokens

    var body: some View {
        Canvas { context, size in
            guard depth > 0 else { return }
            let cw = TreeLayout.columnWidth
            let leadingPad = Spacing.md
            let lineColor = Color(tokens.textMuted).opacity(0.3)
            for level in 1...depth {
                let x = leadingPad + (CGFloat(level) - 0.5) * cw
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            }
        }
    }
}

