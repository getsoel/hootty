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
    var onToggleCollapse: ((UUID) -> Void)?
    var onSave: (() -> Void)?
    @Binding var sidebarHasFocus: Bool
    @Binding var sidebarCursorTarget: SidebarCursorTarget?
    var sidebarWidth: CGFloat
    let isEffectivelyCollapsed: (UUID) -> Bool

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
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @State private var sidebarIsHovered = false
    @State private var scrollTargetRatio: CGFloat?
    let collapsedWorkspaceIDs: Set<UUID>

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
        .onKeyPress(.leftArrow) { handleLeftArrow(); return .handled }
        .onKeyPress(.rightArrow) { handleRightArrow(); return .handled }
        .onKeyPress(.return) { confirmCursor(); return .handled }
        .onKeyPress(.escape) { sidebarHasFocus = false; return .handled }
        .onChange(of: sidebarHasFocus) { _, hasFocus in
            isFocused = hasFocus
            if hasFocus {
                if let paneID = selectedWorkspace?.focusedPaneID {
                    sidebarCursorTarget = .pane(paneID)
                }
            } else {
                sidebarCursorTarget = nil
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

    private var statusCounts: AttentionCounts {
        workspaces.reduce(.zero) { $0 + $1.attentionCounts }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 0) {
            attentionBadges
                .padding(.leading, Spacing.sm)

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

    private var attentionBadges: some View {
        let counts = statusCounts
        return HStack(spacing: Spacing.xs) {
            thinkingPill(count: counts.thinking)
            attentionPill(icon: "flag.fill", count: counts.flagged, color: tokens.statusWarning)
            attentionPill(icon: "checkmark.circle", count: counts.done, color: tokens.statusDone)
            attentionPill(icon: "bell", count: counts.bell, color: tokens.statusBell)
        }
    }

    private func thinkingPill(count: Int) -> some View {
        HStack(spacing: 3) {
            if count > 0 {
                TimelineView(.animation) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.5) / 1.5 * 360
                    Image(systemName: "arrow.2.circlepath")
                        .rotationEffect(.degrees(cycle))
                }
            } else {
                Image(systemName: "arrow.2.circlepath")
            }
            Text("\(count)")
        }
        .font(.system(size: TypeScale.smallSize, weight: .medium))
        .foregroundStyle(Color(count > 0 ? tokens.statusThinking : tokens.textMuted))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(count > 0 ? tokens.statusThinking : tokens.textMuted).opacity(0.15))
        )
    }

    private func attentionPill(icon: String, count: Int, color: NSColor) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text("\(count)")
        }
        .font(.system(size: TypeScale.smallSize, weight: .medium))
        .foregroundStyle(Color(count > 0 ? color : tokens.textMuted))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(count > 0 ? color : tokens.textMuted).opacity(0.15))
        )
    }

    private var scrollTargetIDs: [UUID] {
        var ids: [UUID] = []
        for workspace in workspaces {
            ids.append(workspace.id)
            if !isEffectivelyCollapsed(workspace.id) {
                for section in workspace.sidebarSections {
                    for pane in section.panes {
                        ids.append(pane.id)
                    }
                }
            }
        }
        return ids
    }

    private var workspaceList: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ForEach(workspaces) { workspace in
                        let isActive = workspace.id == selectedWorkspaceID
                        let collapsed = isEffectivelyCollapsed(workspace.id)
                        VStack(spacing: 0) {
                            WorkspaceRow(
                                workspace: workspace,
                                isSelected: isActive,
                                isCollapsed: collapsed,
                                isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .workspace(workspace.id),
                                summaryAttention: collapsed ? workspaceAttentionSummary(workspace) : nil,
                                tokens: tokens,
                                onSelect: { selectedWorkspaceID = workspace.id },
                                onRename: { id, name in
                                    editingName = name
                                    renameTargetID = id
                                    showRenameWorkspaceAlert = true
                                },
                                onRemove: onRemoveWorkspace,
                                onToggleCollapse: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        onToggleCollapse?(workspace.id)
                                    }
                                },
                                onMove: { sourceID, edge in
                                    guard let targetIndex = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
                                    let insertIndex = edge == .top ? targetIndex : targetIndex + 1
                                    onMoveWorkspace(sourceID, insertIndex)
                                },
                                dropTargetWorkspaceID: $dropTargetWorkspaceID,
                                dropEdge: $dropEdge,
                                workspaceRowHeight: $workspaceRowHeight
                            )
                            .id(workspace.id)
                            if !collapsed {
                                workspacePaneList(workspace)
                            }
                        }
                        .background {
                            if isActive {
                                Color(tokens.elementHover)
                            }
                        }
                    }
                }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("sidebarScroll")), initial: true) { _, frame in
                                scrollOffset = -frame.minY
                                contentHeight = frame.height
                            }
                    }
                }
                .onChange(of: scrollTargetRatio) { _, ratio in
                    guard let ratio else { return }
                    let ids = scrollTargetIDs
                    guard !ids.isEmpty else { return }
                    let index = min(Int(ratio * CGFloat(ids.count)), ids.count - 1)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(ids[index], anchor: .top)
                    }
                    scrollTargetRatio = nil
                }
                .onChange(of: selectedWorkspace?.focusedPaneID) { _, paneID in
                    guard let paneID else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(paneID, anchor: .center)
                    }
                }
            }
        }
        .coordinateSpace(name: "sidebarScroll")
        .scrollIndicators(.never)
        .overlay(alignment: .trailing) {
            SidebarScrollbar(
                contentHeight: contentHeight,
                visibleHeight: visibleHeight,
                scrollOffset: scrollOffset,
                tokens: tokens,
                sidebarHovered: sidebarIsHovered,
                onScroll: { ratio in
                    scrollTargetRatio = ratio
                }
            )
        }
        .onHover { hovering in
            sidebarIsHovered = hovering
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.size.height, initial: true) { _, height in
                        visibleHeight = height
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
                BranchSectionHeader(section: section, isSelected: workspace.id == selectedWorkspaceID, focusedPaneID: workspace.focusedPaneID, tokens: tokens)
            }

            ForEach(section.panes) { pane in
                SidebarPaneRow(
                    pane: pane,
                    isFocusedPane: workspace.focusedPaneID == pane.id && workspace.id == selectedWorkspaceID,
                    isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .pane(pane.id),
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
                .id(pane.id)
            }
        }
    }

    // MARK: - Attention Summary

    private func workspaceAttentionSummary(_ workspace: Workspace) -> WorkspaceAttentionSummary? {
        var hasDone = false
        var hasBell = false
        for pane in workspace.allPanes {
            if pane.isThinking { return .thinking }
            switch pane.attentionKind {
            case .done: hasDone = true
            case .bell: hasBell = true
            case nil: break
            }
        }
        if hasDone { return .done }
        if hasBell { return .bell }
        return nil
    }

    // MARK: - Rename

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
        sidebarCursorTarget = SidebarKeyboardNav.moveCursor(
            direction: direction,
            workspaces: workspaces,
            collapsedWorkspaceIDs: collapsedWorkspaceIDs,
            selectedWorkspaceID: selectedWorkspaceID,
            currentTarget: sidebarCursorTarget
        )
    }

    private func handleLeftArrow() {
        guard let target = sidebarCursorTarget else { return }
        switch target {
        case let .workspace(id):
            // Collapse the workspace
            if !collapsedWorkspaceIDs.contains(id) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggleCollapse?(id)
                }
            }
        case let .pane(paneID):
            // Jump cursor to parent workspace row
            if let wsID = SidebarKeyboardNav.workspaceForPane(paneID: paneID, workspaces: workspaces) {
                sidebarCursorTarget = .workspace(wsID)
            }
        }
    }

    private func handleRightArrow() {
        guard let target = sidebarCursorTarget else { return }
        if case let .workspace(id) = target {
            // Expand the workspace
            if collapsedWorkspaceIDs.contains(id) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggleCollapse?(id)
                }
            }
        }
    }

    private func confirmCursor() {
        guard let target = sidebarCursorTarget else {
            sidebarHasFocus = false
            return
        }
        let item = SidebarKeyboardNav.confirmCursor(
            target: target,
            workspaces: workspaces,
            collapsedWorkspaceIDs: collapsedWorkspaceIDs,
            selectedWorkspaceID: selectedWorkspaceID
        )
        switch item {
        case let .workspace(id):
            selectedWorkspaceID = id
        case let .pane(workspaceID, paneID):
            onSelectPane(workspaceID, paneID)
        case nil:
            break
        }
        sidebarHasFocus = false
    }
}

/// Summary of the highest-priority attention state for a collapsed workspace row.
enum WorkspaceAttentionSummary {
    case thinking
    case done
    case bell
}
