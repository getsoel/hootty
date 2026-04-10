import HoottyCore
import SwiftUI

struct CondensedSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let tokens: DesignTokens
    var onExpandSidebar: () -> Void
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onSelectPane: (UUID, UUID) -> Void
    var onRemovePane: (UUID, UUID) -> Void
    var onToggleCollapse: (UUID) -> Void
    var onSave: () -> Void
    let isEffectivelyCollapsed: (UUID) -> Bool
    let collapsedWorkspaceIDs: Set<UUID>
    let activeSidebarFilters: Set<SidebarFilter>
    @Binding var sidebarHasFocus: Bool
    @Binding var sidebarCursorTarget: SidebarCursorTarget?
    var pinnedWorkspaceID: UUID?

    @FocusState private var isFocused: Bool
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renamePaneTargetID: UUID?
    @State private var editingPaneName: String = ""
    @State private var showRenameWorkspaceAlert = false
    @State private var showRenamePaneAlert = false

    var body: some View {
        VStack(spacing: 0) {
            expandHeader
            addWorkspaceHeader
            if let pinned = pinnedWorkspace {
                workspaceSection(pinned)
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
            scrollContent
            Spacer(minLength: 0)
        }
        .frame(width: Layout.condensedSidebarWidth)
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
                let selected = workspaces.first { $0.id == selectedWorkspaceID }
                if let paneID = selected?.focusedPaneID {
                    sidebarCursorTarget = .pane(paneID)
                }
            } else {
                sidebarCursorTarget = nil
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, sidebarHasFocus { sidebarHasFocus = false }
        }
        .contextMenu {
            Button("New Workspace") { onAddWorkspace() }
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

    // MARK: - Header

    private var expandHeader: some View {
        railChromeRow(systemImage: "sidebar.left", label: "Expand sidebar", action: onExpandSidebar)
    }

    private var addWorkspaceHeader: some View {
        railChromeRow(systemImage: "plus", label: "New workspace", action: onAddWorkspace)
    }

    private func railChromeRow(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            BarIconButton(
                systemImage: systemImage,
                tokens: tokens,
                accessibilityLabel: label,
                help: label,
                action: action
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
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

    // MARK: - Scroll Content

    private var scrollContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(scrollableWorkspaces) { workspace in
                        workspaceSection(workspace)
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
    }

    // MARK: - Workspace Section

    @ViewBuilder
    private func workspaceSection(_ workspace: Workspace) -> some View {
        let isActive = workspace.id == selectedWorkspaceID
        let collapsed = isEffectivelyCollapsed(workspace.id)

        VStack(spacing: 0) {
            workspaceRow(workspace: workspace, isActive: isActive, isCollapsed: collapsed)

            if !collapsed {
                workspacePaneRows(workspace, isActive: isActive)
            }
        }
        .background {
            if isActive {
                Color(tokens.elementHover)
            }
        }
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle()
                    .fill(Color(tokens.textAccent))
                    .frame(width: 2)
            }
        }
    }

    private func workspaceRow(workspace: Workspace, isActive: Bool, isCollapsed: Bool) -> some View {
        WorkspaceRailRow(
            workspace: workspace,
            isActive: isActive,
            isCollapsed: isCollapsed,
            isPinned: workspace.id == pinnedWorkspaceID,
            isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .workspace(workspace.id),
            tokens: tokens,
            onToggleCollapse: { onToggleCollapse(workspace.id) }
        )
        .contextMenu {
            Button("Rename Workspace") {
                editingName = workspace.name
                renameTargetID = workspace.id
                showRenameWorkspaceAlert = true
            }
            Button(isCollapsed ? "Expand" : "Collapse") {
                onToggleCollapse(workspace.id)
            }
            Button("Close Workspace") {
                onRemoveWorkspace(workspace.id)
            }
        }
    }

    @ViewBuilder
    private func workspacePaneRows(_ workspace: Workspace, isActive: Bool) -> some View {
        let hasBranches = workspace.hasBranchSections
        let sections = workspace.sidebarSections

        ForEach(sections) { section in
            let filteredPanes = section.panes.filter { pane in
                pane.isVisibleInSidebar(
                    isFocusedInSelectedWorkspace: isActive && pane.id == workspace.focusedPaneID,
                    filters: activeSidebarFilters
                )
            }

            if !filteredPanes.isEmpty {
                if hasBranches {
                    branchSectionRow(section: section, isActive: isActive)
                }

                ForEach(filteredPanes) { pane in
                    paneRow(
                        pane: pane,
                        isFocused: workspace.focusedPaneID == pane.id && isActive,
                        isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .pane(pane.id),
                        action: { onSelectPane(workspace.id, pane.id) }
                    )
                    .contextMenu {
                        Button("Rename Pane") {
                            editingPaneName = pane.displayName
                            renamePaneTargetID = pane.id
                            showRenamePaneAlert = true
                        }
                        if workspace.allPanes.count > 1 {
                            Button("Close Pane") {
                                onRemovePane(workspace.id, pane.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func branchSectionRow(section: SidebarSection, isActive: Bool) -> some View {
        let iconName = if section.branch == nil {
            "cube.transparent"
        } else if section.isHead {
            "cube.fill"
        } else {
            "cube"
        }

        return condensedRow(
            icon: iconName,
            color: isActive ? tokens.text : tokens.textMuted,
            tooltip: section.displayLabel ?? "No Branch",
            action: {}
        )
    }

    // MARK: - Pane Row

    private func paneRow(pane: Pane, isFocused: Bool, isCursorTarget: Bool = false, action: @escaping () -> Void) -> some View {
        PaneRailRow(
            pane: pane,
            isFocused: isFocused,
            isCursorTarget: isCursorTarget,
            tokens: tokens,
            action: action
        )
    }

    // MARK: - Shared Row

    private func condensedRow(
        icon: String,
        color: NSColor,
        tooltip: String,
        isCursorTarget: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        CondensedRowView(
            icon: icon,
            color: color,
            tooltip: tooltip,
            isCursorTarget: isCursorTarget,
            tokens: tokens,
            action: action
        )
    }

    // MARK: - Rename

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let target = workspaces.first(where: { $0.id == renameTargetID }) {
            target.name = trimmed
            onSave()
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
                    onSave()
                    break
                }
            }
        }
        renamePaneTargetID = nil
        showRenamePaneAlert = false
    }

    // MARK: - Keyboard Navigation

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
                    onToggleCollapse(id)
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
                    onToggleCollapse(id)
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

// MARK: - Condensed Row View

private struct CondensedRowView: View {
    let icon: String
    let color: NSColor
    let tooltip: String
    var isCursorTarget: Bool = false
    let tokens: DesignTokens
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: TypeScale.smallSize))
            .foregroundStyle(Color(color))
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                Rectangle().fill(isHovered || isCursorTarget ? Color(tokens.elementHover) : Color.clear)
            )
            .help(tooltip)
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                    DispatchQueue.main.async { NSCursor.pointingHand.set() }
                case .ended:
                    isHovered = false
                @unknown default: break
                }
            }
    }
}

// MARK: - Workspace Rail Row

private struct WorkspaceRailRow: View {
    let workspace: Workspace
    let isActive: Bool
    let isCollapsed: Bool
    let isPinned: Bool
    var isCursorTarget: Bool = false
    let tokens: DesignTokens
    let onToggleCollapse: () -> Void

    private var iconName: String {
        isPinned ? "pin.fill" : (isCollapsed ? "folder" : "folder.fill")
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: TypeScale.smallSize))
            .foregroundStyle(Color(isActive ? tokens.text : tokens.textMuted))
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                Rectangle().fill(isCursorTarget ? Color(tokens.elementHover) : Color.clear)
            )
            .help(workspace.name)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggleCollapse()
                }
            }
            .onContinuousHover { phase in
                if case .active = phase {
                    DispatchQueue.main.async { NSCursor.pointingHand.set() }
                }
            }
    }
}

// MARK: - Pane Rail Row

private struct PaneRailRow: View {
    let pane: Pane
    let isFocused: Bool
    var isCursorTarget: Bool = false
    let tokens: DesignTokens
    let action: () -> Void

    var body: some View {
        Group {
            if pane.isThinking {
                TimelineView(.animation) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.5) / 1.5 * 360
                    Image(systemName: icon)
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(color))
                        .rotationEffect(.degrees(cycle))
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
            } else {
                Image(systemName: icon)
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(color))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
        }
        .background(paneBackground)
        .help(pane.displayName)
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .onContinuousHover { phase in
            if case .active = phase {
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            }
        }
    }

    private var icon: String {
        if pane.attentionKind == .done {
            "checkmark.circle"
        } else if pane.attentionKind == .bell {
            "bell"
        } else if pane.isThinking {
            "arrow.2.circlepath"
        } else if pane.agentSessionID != nil {
            "bubble.left"
        } else {
            "apple.terminal"
        }
    }

    private var color: NSColor {
        if pane.attentionKind == .done {
            tokens.statusDone
        } else if pane.attentionKind == .bell {
            tokens.statusBell
        } else if pane.isThinking {
            tokens.statusThinking
        } else {
            isFocused ? tokens.text : tokens.textMuted
        }
    }

    @ViewBuilder
    private var paneBackground: some View {
        if isCursorTarget {
            Rectangle().fill(Color(tokens.elementHover))
        } else if isFocused {
            Rectangle().fill(Color(tokens.elementSelected))
        } else if let kind = pane.attentionKind {
            Rectangle().fill(Color(tokens.attentionColor(for: kind)).opacity(0.20))
        } else if pane.isThinking {
            Rectangle().fill(Color(tokens.statusThinking).opacity(0.20))
        } else if pane.isFlagged {
            Rectangle().fill(Color(tokens.statusWarning).opacity(0.15))
        }
    }
}
