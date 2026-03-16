import HoottyCore
import SwiftUI
import UniformTypeIdentifiers

private enum SidebarTab: String, CaseIterable {
    case terminals = "Terminals"
    case board = "Board"

    init(_ detailMode: AppModel.DetailMode) {
        switch detailMode {
        case .terminals: self = .terminals
        case .board: self = .board
        }
    }

    var detailMode: AppModel.DetailMode {
        switch self {
        case .terminals: .terminals
        case .board: .board
        }
    }
}

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let tokens: DesignTokens
    @Binding var detailMode: AppModel.DetailMode
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
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renamePaneTargetID: UUID?
    @State private var editingPaneName: String = ""
    @State private var worktreeTarget: WorktreeCreationTarget?
    @State private var worktreeBranchName: String = ""
    @State private var dropTargetWorkspaceID: UUID?
    @State private var dropEdge: VerticalEdge?
    @State private var workspaceRowHeight: CGFloat = 32
    @Binding var showWorktreeActions: Bool
    @State private var hoveredHeaderButton: String?
    @State private var hoveredWorktreeAction: String?

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
            if !focused, sidebarHasFocus { sidebarHasFocus = false }
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
            sidebarTabPicker
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

    private var sidebarTabPicker: some View {
        let activeTab = SidebarTab(detailMode)
        return HStack(spacing: 2) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Text(tab.rawValue)
                    .font(.system(size: TypeScale.captionSize, weight: activeTab == tab ? .medium : .regular))
                    .foregroundStyle(Color(activeTab == tab ? tokens.text : tokens.textMuted))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs + 1)
                    .background(
                        Capsule()
                            .fill(activeTab == tab ? Color(tokens.elementSelected) : Color.clear)
                    )
                    .contentShape(Capsule())
                    .onTapGesture { detailMode = tab.detailMode }
            }
        }
        .padding(2)
        .background(
            Capsule()
                .fill(Color(tokens.surfaceHighlight).opacity(0.3))
        )
    }

    private var workspaceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(workspaces) { workspace in
                    WorkspaceRow(
                        workspace: workspace,
                        isSelected: workspace.id == selectedWorkspaceID,
                        tokens: tokens,
                        onSelect: { selectedWorkspaceID = workspace.id },
                        onRename: { id, name in
                            editingName = name
                            renameTargetID = id
                        },
                        onRemove: onRemoveWorkspace,
                        onMove: { sourceID, edge in
                            guard let targetIndex = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
                            let insertIndex = edge == .top ? targetIndex : targetIndex + 1
                            onMoveWorkspace(sourceID, insertIndex)
                        },
                        dropTargetWorkspaceID: $dropTargetWorkspaceID,
                        dropEdge: $dropEdge,
                        workspaceRowHeight: $workspaceRowHeight
                    )
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
                BranchSectionHeader(section: section, tokens: tokens)
            }

            ForEach(section.panes) { pane in
                SidebarPaneRow(
                    pane: pane,
                    isFocusedPane: workspace.focusedPaneID == pane.id && workspace.id == selectedWorkspaceID,
                    isCursorTarget: sidebarHasFocus && sidebarCursorPaneID == pane.id,
                    canClose: canClose,
                    layoutRects: layoutRects,
                    depth: depth,
                    tokens: tokens,
                    onSelect: {
                        sidebarHasFocus = true
                        onSelectPane(workspace.id, pane.id)
                    },
                    onRename: { id, name in
                        editingPaneName = name
                        renamePaneTargetID = id
                    },
                    onClose: { id in
                        onRemovePane(workspace.id, id)
                    }
                )
            }

            // Show "+ New worktree" at the end of each repo's group
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
              let idx = items.firstIndex(where: { $0.paneID == currentID })
        else {
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
