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
    var onResumePane: ((UUID) -> Void)?
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
    @State private var entryHeights: [UUID: CGFloat] = [:]
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
    var onToggleSidebar: (() -> Void)?
    var pinnedWorkspaceID: UUID?
    var onTogglePinWorkspace: ((UUID) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if let pinned = pinnedWorkspace {
                VStack(spacing: 0) {
                    workspaceEntry(pinned)
                    Rectangle().fill(Color(tokens.border)).frame(height: 1)
                }
                .background(Color(tokens.surfaceLow))
                .shadow(color: Color.black.opacity(pinnedShadowOpacity), radius: 4, x: 0, y: 2)
                .zIndex(1)
            }

            workspaceList

            Spacer(minLength: 0)
        }
        .frame(width: sidebarWidth)
        .background(Color(tokens.surfaceLow))
        .overlay(alignment: .bottom) {
            attentionBadges
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl + Spacing.sm)
        }
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
        workspaces.reduce(.zero) { $0 + $1.attentionCounts }
    }

    /// Opacity for the shadow cast by the pinned workspace header onto the
    /// scroll content below. Fades in as the sidebar is scrolled so it only
    /// appears when content is passing under the pinned row.
    private var pinnedShadowOpacity: Double {
        let ramp: CGFloat = 8
        let clamped = min(max(scrollOffset, 0), ramp) / ramp
        return Double(clamped) * 0.35
    }

    /// Vertical space reserved at the bottom of the scroll content so the
    /// floating filter pill doesn't obscure the last workspace row when
    /// scrolled to the end. Sized to fit the regular-size pill plus its
    /// bottom overlay margin plus a gap for breathing room.
    private var floatingBarScrollReserve: CGFloat {
        Layout.barHeight + Spacing.xl + Spacing.md
    }

    private var sidebarHeader: some View {
        HStack(spacing: 0) {
            Text("Workspaces")
                .font(.system(size: TypeScale.bodySize, weight: .medium))
                .foregroundStyle(Color(tokens.text))
                .padding(.leading, Spacing.md)

            Spacer(minLength: 0)

            HStack(spacing: Spacing.xs) {
                BarIconButton(
                    systemImage: "sidebar.left",
                    tokens: tokens,
                    accessibilityLabel: "Toggle Sidebar",
                    help: "Toggle Sidebar",
                    action: { onToggleSidebar?() }
                )

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
        return BarFilterGroup(
            items: [
                BarFilterItem(filter: .thinking, color: tokens.statusThinking, count: counts.thinking) {
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
                },
                BarFilterItem(filter: .flagged, color: tokens.statusWarning, count: counts.flagged) {
                    Image(systemName: "flag.fill")
                },
                BarFilterItem(filter: .done, color: tokens.statusDone, count: counts.done) {
                    Image(systemName: "checkmark.circle")
                },
                BarFilterItem(filter: .bell, color: tokens.statusBell, count: counts.bell) {
                    Image(systemName: "bell")
                },
                BarFilterItem(filter: .error, color: tokens.statusError, count: counts.error) {
                    Image(systemName: "exclamationmark.triangle")
                }
            ],
            tokens: tokens,
            activeFilters: activeSidebarFilters,
            hidesZeroCounts: false,
            size: .regular,
            onToggle: onToggleSidebarFilter
        )
    }

    private var scrollTargetIDs: [UUID] {
        var ids: [UUID] = []
        for workspace in scrollableWorkspaces {
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

    private var pinnedWorkspace: Workspace? {
        guard let pinnedID = pinnedWorkspaceID else { return nil }
        return workspaces.first { $0.id == pinnedID }
    }

    private var scrollableWorkspaces: [Workspace] {
        guard let pinnedID = pinnedWorkspaceID else { return workspaces }
        return workspaces.filter { $0.id != pinnedID }
    }

    private var sortedWorkspaces: [Workspace] {
        guard let pinned = pinnedWorkspace else { return workspaces }
        return [pinned] + scrollableWorkspaces
    }

    private var workspaceList: some View {
        workspaceScrollView
    }

    @ViewBuilder
    private func workspaceEntry(_ workspace: Workspace) -> some View {
        let isActive = workspace.id == selectedWorkspaceID
        let collapsed = isEffectivelyCollapsed(workspace.id)
        let isPinned = workspace.id == pinnedWorkspaceID
        VStack(spacing: 0) {
            WorkspaceRow(
                workspace: workspace,
                isSelected: isActive,
                isCollapsed: collapsed,
                isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .workspace(workspace.id),
                tokens: tokens,
                isPinned: isPinned,
                onSelect: {
                    if isActive {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            onToggleCollapse?(workspace.id)
                        }
                    } else {
                        selectedWorkspaceID = workspace.id
                        if collapsedWorkspaceIDs.contains(workspace.id) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                onToggleCollapse?(workspace.id)
                            }
                        }
                    }
                },
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
                onTogglePinWorkspace: { onTogglePinWorkspace?(workspace.id) }
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
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.size.height, initial: true) { _, h in
                entryHeights[workspace.id] = h
            }
        })
        .overlay(alignment: dropEdge == .top ? .top : .bottom) {
            if dropTargetWorkspaceID == workspace.id, let edge = dropEdge {
                Rectangle()
                    .fill(Color(tokens.textAccent))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: edge == .top ? -1 : 1)
                    .transition(.identity)
            }
        }
        .onDrop(of: [.utf8PlainText], delegate: WorkspaceEntryDropDelegate(
            workspaceID: workspace.id,
            entryHeight: entryHeights[workspace.id] ?? 32,
            dropTargetWorkspaceID: $dropTargetWorkspaceID,
            dropEdge: $dropEdge,
            onMove: { sourceID, edge in
                guard workspaces.contains(where: { $0.id == sourceID }),
                      let targetIndex = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
                let insertIndex = edge == .top ? targetIndex : targetIndex + 1
                onMoveWorkspace(sourceID, insertIndex)
            }
        ))
    }

    private var workspaceScrollView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ForEach(scrollableWorkspaces) { workspace in
                        workspaceEntry(workspace)
                    }
                    // Reserve space so the floating filter pill doesn't
                    // permanently obscure the last workspace row.
                    Color.clear.frame(height: floatingBarScrollReserve)
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
                .onChange(of: workspaces.map(\.id)) {
                    dropTargetWorkspaceID = nil
                    dropEdge = nil
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
                        onResume: {
                            onResumePane?(pane.id)
                        }
                    )
                    .id(pane.id)
                }
            }
        }
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
            workspaces: sortedWorkspaces,
            collapsedWorkspaceIDs: collapsedWorkspaceIDs,
            selectedWorkspaceID: selectedWorkspaceID,
            currentTarget: sidebarCursorTarget,
            activeFilters: activeSidebarFilters
        )
    }

    private func handleLeftArrow() {
        guard let target = sidebarCursorTarget else { return }
        switch target {
        case let .workspace(id):
            if !collapsedWorkspaceIDs.contains(id) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggleCollapse?(id)
                }
            }
        case let .pane(paneID):
            if let wsID = SidebarKeyboardNav.workspaceForPane(paneID: paneID, workspaces: workspaces) {
                sidebarCursorTarget = .workspace(wsID)
            }
        }
    }

    private func handleRightArrow() {
        guard let target = sidebarCursorTarget else { return }
        if case let .workspace(id) = target {
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

// MARK: - Workspace Drag-and-Drop

private struct WorkspaceEntryDropDelegate: DropDelegate {
    let workspaceID: UUID
    let entryHeight: CGFloat
    @Binding var dropTargetWorkspaceID: UUID?
    @Binding var dropEdge: VerticalEdge?
    let onMove: (UUID, VerticalEdge) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.utf8PlainText])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let newEdge: VerticalEdge = info.location.y < entryHeight / 2 ? .top : .bottom
        if dropEdge != newEdge || dropTargetWorkspaceID != workspaceID {
            dropEdge = newEdge
            dropTargetWorkspaceID = workspaceID
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.utf8PlainText]).first else { return false }
        let capturedOnMove = onMove
        let capturedEdge = dropEdge ?? .bottom

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
