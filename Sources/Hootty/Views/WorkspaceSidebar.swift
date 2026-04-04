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
    let activeSidebarFilters: Set<SidebarFilter>
    var onToggleSidebarFilter: ((SidebarFilter) -> Void)?
    var onClearSidebarFilters: (() -> Void)?

    // Persistent panel
    var persistentNode: SplitNode?
    var persistentFocusedPaneID: UUID?
    @Binding var persistentSidebarCollapsed: Bool
    var onSelectPersistentPane: ((UUID) -> Void)?
    var onRemovePersistentPane: ((UUID) -> Void)?
    var onNewPersistentPane: (() -> Void)?
    var onCloseAllPersistentPanes: (() -> Void)?
    var onMovePaneToWorkspace: ((UUID, UUID) -> Void)?
    var onMovePaneToPinned: ((UUID) -> Void)?

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
        .onKeyPress(.escape) {
            if !activeSidebarFilters.isEmpty {
                onClearSidebarFilters?()
            } else {
                sidebarHasFocus = false
            }
            return .handled
        }
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
        let base = workspaces.reduce(.zero) { $0 + $1.attentionCounts }
        guard let panes = persistentNode?.allPanes() else { return base }
        return base + AttentionCounts(panes: panes, focusedPaneID: persistentFocusedPaneID)
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
            filterPill(filter: .thinking, count: counts.thinking, color: tokens.statusThinking) {
                if counts.thinking > 0 {
                    TimelineView(.animation) { context in
                        let cycle = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 1.5) / 1.5 * 360
                        Image(systemName: "arrow.2.circlepath")
                            .rotationEffect(.degrees(cycle))
                    }
                } else {
                    Image(systemName: "arrow.2.circlepath")
                }
            }
            filterPill(filter: .flagged, count: counts.flagged, color: tokens.statusWarning) {
                Image(systemName: "flag.fill")
            }
            filterPill(filter: .done, count: counts.done, color: tokens.statusDone) {
                Image(systemName: "checkmark.circle")
            }
            filterPill(filter: .bell, count: counts.bell, color: tokens.statusBell) {
                Image(systemName: "bell")
            }
        }
    }

    private func filterPill(filter: SidebarFilter, count: Int, color: NSColor, @ViewBuilder icon: () -> some View) -> some View {
        let isFilterActive = activeSidebarFilters.contains(filter)
        let active = isFilterActive || count > 0
        let pillColor = Color(active ? color : tokens.textMuted)
        return HStack(spacing: 3) {
            icon()
            Text("\(count)")
        }
        .font(.system(size: TypeScale.smallSize, weight: .medium))
        .foregroundStyle(pillColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(pillColor.opacity(isFilterActive ? 0.3 : 0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(pillColor.opacity(0.6), lineWidth: isFilterActive ? 1 : 0)
        )
        .contentShape(Capsule())
        .onTapGesture { onToggleSidebarFilter?(filter) }
        .onContinuousHover { phase in
            if case .active = phase {
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            }
        }
    }

    private var scrollTargetIDs: [UUID] {
        var ids: [UUID] = []
        for workspace in workspaces {
            ids.append(workspace.id)
            if !isEffectivelyCollapsed(workspace.id) {
                let isSelectedWs = workspace.id == selectedWorkspaceID
                for section in workspace.sidebarSections {
                    for pane in section.panes where pane.isVisibleInSidebar(isFocusedInSelectedWorkspace: isSelectedWs && pane.id == workspace.focusedPaneID, filters: activeSidebarFilters) {
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
                    // Persistent panel pseudo-workspace
                    if persistentNode != nil {
                        persistentPanelSection
                    }

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
        let isSelectedWs = workspace.id == selectedWorkspaceID

        let sections = workspace.sidebarSections
        ForEach(sections) { section in
            let filteredPanes = section.panes.filter { pane in
                pane.isVisibleInSidebar(isFocusedInSelectedWorkspace: isSelectedWs && pane.id == workspace.focusedPaneID, filters: activeSidebarFilters)
            }

            if !filteredPanes.isEmpty {
                if hasBranches {
                    BranchSectionHeader(section: section, isSelected: isSelectedWs, focusedPaneID: workspace.focusedPaneID, tokens: tokens)
                }

                ForEach(filteredPanes) { pane in
                    SidebarPaneRow(
                        pane: pane,
                        isFocusedPane: workspace.focusedPaneID == pane.id && isSelectedWs,
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
                        },
                        onMoveToPinned: {
                            onMovePaneToPinned?(pane.id)
                        }
                    )
                    .id(pane.id)
                }
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
            currentTarget: sidebarCursorTarget,
            activeFilters: activeSidebarFilters,
            persistentNode: persistentNode,
            persistentSidebarCollapsed: persistentSidebarCollapsed,
            persistentFocusedPaneID: persistentFocusedPaneID
        )
    }

    private func handleLeftArrow() {
        guard let target = sidebarCursorTarget else { return }
        switch target {
        case let .workspace(id):
            if id == AppModel.persistentWorkspaceID {
                if !persistentSidebarCollapsed {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        persistentSidebarCollapsed = true
                    }
                }
            } else if !collapsedWorkspaceIDs.contains(id) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggleCollapse?(id)
                }
            }
        case let .pane(paneID):
            if let wsID = SidebarKeyboardNav.workspaceForPane(paneID: paneID, workspaces: workspaces, persistentNode: persistentNode) {
                sidebarCursorTarget = .workspace(wsID)
            }
        }
    }

    private func handleRightArrow() {
        guard let target = sidebarCursorTarget else { return }
        if case let .workspace(id) = target {
            if id == AppModel.persistentWorkspaceID {
                if persistentSidebarCollapsed {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        persistentSidebarCollapsed = false
                    }
                }
            } else if collapsedWorkspaceIDs.contains(id) {
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
            if id == AppModel.persistentWorkspaceID {
                withAnimation(.easeInOut(duration: 0.15)) {
                    persistentSidebarCollapsed.toggle()
                }
                return // Don't exit sidebar focus
            }
            selectedWorkspaceID = id
        case let .pane(workspaceID, paneID):
            if workspaceID == AppModel.persistentWorkspaceID {
                onSelectPersistentPane?(paneID)
            } else {
                onSelectPane(workspaceID, paneID)
            }
        case nil:
            break
        }
        sidebarHasFocus = false
    }

    // MARK: - Persistent Panel Section

    @ViewBuilder
    private var persistentPanelSection: some View {
        let isCursor = sidebarHasFocus && sidebarCursorTarget == .workspace(AppModel.persistentWorkspaceID)

        VStack(spacing: 0) {
            // Row
            HStack(spacing: Spacing.sm) {
                Image(systemName: "pin.fill")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.textMuted))

                if let summary = persistentAttentionSummary, persistentSidebarCollapsed {
                    StatusDotView(
                        attentionKind: summary == .done ? .done : summary == .bell ? .bell : nil,
                        isThinking: summary == .thinking,
                        isClaudeSession: false,
                        tokens: tokens
                    )
                }

                Text("Pinned")
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.text))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Rectangle().fill(Color.clear))
            .overlay {
                if isCursor {
                    Rectangle()
                        .strokeBorder(Color(tokens.borderFocused), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    persistentSidebarCollapsed.toggle()
                }
            }
            .contextMenu {
                Button("New Pane") { onNewPersistentPane?() }
                Divider()
                Button("Close All") { onCloseAllPersistentPanes?() }
            }

            // Pane rows
            if !persistentSidebarCollapsed, let node = persistentNode {
                let panes = node.allPanes()
                let canClose = panes.count > 1
                ForEach(panes) { pane in
                    SidebarPaneRow(
                        pane: pane,
                        isFocusedPane: persistentFocusedPaneID == pane.id,
                        isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .pane(pane.id),
                        canClose: canClose,
                        layoutRects: [:],
                        showLayoutThumbnails: false,
                        depth: 1,
                        tokens: tokens,
                        onSelect: {
                            sidebarHasFocus = false
                            onSelectPersistentPane?(pane.id)
                        },
                        onRename: { id, name in
                            editingPaneName = name
                            renamePaneTargetID = id
                            showRenamePaneAlert = true
                        },
                        onClose: { id in onRemovePersistentPane?(id) },
                        onToggleNote: { onToggleNote?(pane.id) }
                    )
                    .id(pane.id)
                    .contextMenu {
                        Button("Close Pane") { onRemovePersistentPane?(pane.id) }
                        if !workspaces.isEmpty {
                            Menu("Move to Workspace") {
                                ForEach(workspaces) { ws in
                                    Button(ws.name) {
                                        onMovePaneToWorkspace?(pane.id, ws.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Divider between persistent and workspaces
        Rectangle()
            .fill(Color(tokens.border))
            .frame(height: 1)
    }

    private var persistentAttentionSummary: WorkspaceAttentionSummary? {
        guard let panes = persistentNode?.allPanes() else { return nil }
        var hasDone = false
        var hasBell = false
        for pane in panes {
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
}

/// Summary of the highest-priority attention state for a collapsed workspace row.
enum WorkspaceAttentionSummary {
    case thinking
    case done
    case bell
}
