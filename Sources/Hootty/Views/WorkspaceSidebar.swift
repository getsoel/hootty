import HoottyCore
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let tokens: DesignTokens
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onMoveWorkspace: (UUID, Int) -> Void
    var onSelectPane: (UUID, UUID) -> Void
    var onRemovePane: (UUID, UUID) -> Void
    var onToggleNote: ((UUID) -> Void)?
    var onSave: (() -> Void)?
    @Binding var sidebarHasFocus: Bool
    @Binding var sidebarCursorPaneID: UUID?
    var sidebarWidth: CGFloat

    @FocusState private var isFocused: Bool
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renamePaneTargetID: UUID?
    @State private var editingPaneName: String = ""
    @State private var dropTargetWorkspaceID: UUID?
    @State private var dropEdge: VerticalEdge?
    @State private var workspaceRowHeight: CGFloat = 32
    @Binding var showLayoutThumbnails: Bool
    @State private var showRenameWorkspaceAlert = false
    @State private var showRenamePaneAlert = false

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
        .alert("Rename Workspace", isPresented: $showRenameWorkspaceAlert) {
            TextField("Workspace name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Rename Pane", isPresented: $showRenamePaneAlert) {
            TextField("Pane name", text: $editingPaneName)
            Button("OK") { commitPaneRename() }
            Button("Cancel", role: .cancel) { renamePaneTargetID = nil }
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 0) {
            sidebarTabPicker
                .padding(.leading, Spacing.md)

            Spacer(minLength: 0)

            HStack(spacing: Spacing.xs) {
                BarIconButton(
                    systemImage: "squareshape.split.2x2",
                    tokens: tokens,
                    accessibilityLabel: "Toggle layout thumbnails",
                    help: "Toggle layout thumbnails",
                    iconColor: showLayoutThumbnails ? tokens.textAccent : tokens.textMuted,
                    action: { showLayoutThumbnails.toggle() }
                )

                BarIconButton(
                    systemImage: "plus",
                    tokens: tokens,
                    accessibilityLabel: "New workspace",
                    help: "Create new workspace",
                    action: onAddWorkspace
                )
            }
            .padding(Spacing.smd)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color(tokens.border)).frame(width: 1)
            }
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var sidebarTabPicker: some View {
        Text("Workspaces")
            .font(.system(size: TypeScale.captionSize, weight: .semibold))
            .foregroundStyle(Color(tokens.textMuted))
    }

    private var workspaceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(workspaces) { workspace in
                    let isActive = workspace.id == selectedWorkspaceID
                    VStack(spacing: 0) {
                        WorkspaceRow(
                            workspace: workspace,
                            isSelected: isActive,
                            tokens: tokens,
                            onSelect: { selectedWorkspaceID = workspace.id },
                            onRename: { id, name in
                                editingName = name
                                renameTargetID = id
                                showRenameWorkspaceAlert = true
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
                    .background {
                        if isActive {
                            Color(tokens.elementHover)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func workspacePaneList(_ workspace: Workspace) -> some View {
        let canClose = workspace.allPanes.count > 1
        let layoutRects = (canClose && showLayoutThumbnails) ? workspace.rootNode.paneRects() : [:]
        let hasBranches = workspace.hasBranchSections
        let depth = hasBranches ? 2 : 1

        let sections = workspace.sidebarSections
        ForEach(sections) { section in
            if hasBranches {
                BranchSectionHeader(section: section, isSelected: workspace.id == selectedWorkspaceID, tokens: tokens)
            }

            ForEach(section.panes) { pane in
                SidebarPaneRow(
                    pane: pane,
                    isFocusedPane: workspace.focusedPaneID == pane.id && workspace.id == selectedWorkspaceID,
                    isCursorTarget: sidebarHasFocus && sidebarCursorPaneID == pane.id,
                    canClose: canClose,
                    layoutRects: layoutRects,
                    showLayoutThumbnails: showLayoutThumbnails,
                    depth: depth,
                    tokens: tokens,
                    onSelect: {
                        sidebarHasFocus = false
                        onSelectPane(workspace.id, pane.id)
                    },
                    onRename: { id, name in
                        editingPaneName = name
                        renamePaneTargetID = id
                        showRenamePaneAlert = true
                    },
                    onClose: { id in
                        onRemovePane(workspace.id, id)
                    },
                    onToggleNote: {
                        onToggleNote?(pane.id)
                    }
                )
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
        showRenameWorkspaceAlert = false
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
        showRenamePaneAlert = false
    }

    // MARK: - Keyboard Navigation

    private var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    private func moveCursor(direction: Int) {
        sidebarCursorPaneID = SidebarKeyboardNav.moveCursor(
            direction: direction,
            workspaces: workspaces,
            selectedWorkspaceID: selectedWorkspaceID,
            currentCursorPaneID: sidebarCursorPaneID
        )
    }

    private func confirmCursor() {
        if let item = SidebarKeyboardNav.confirmCursor(
            cursorPaneID: sidebarCursorPaneID,
            workspaces: workspaces
        ) {
            onSelectPane(item.workspaceID, item.paneID)
        }
        sidebarHasFocus = false
    }
}
