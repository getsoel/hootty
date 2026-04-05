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

    // Persistent panel
    var persistentNode: SplitNode?
    var persistentFocusedPaneID: UUID?
    @Binding var persistentSidebarCollapsed: Bool
    var onSelectPersistentPane: ((UUID) -> Void)?
    var onRemovePersistentPane: ((UUID) -> Void)?
    var onNewPersistentPane: (() -> Void)?
    var onMovePaneToPinned: ((UUID) -> Void)?
    var onMovePaneToWorkspace: ((UUID, UUID) -> Void)?
    @Binding var sidebarHasFocus: Bool
    @Binding var sidebarCursorTarget: SidebarCursorTarget?

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
            if persistentNode != nil {
                Button("New Docked Pane") { onNewPersistentPane?() }
            }
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
        HStack(spacing: 0) {
            BarIconButton(
                systemImage: "sidebar.left",
                tokens: tokens,
                accessibilityLabel: "Expand sidebar",
                help: "Expand sidebar",
                action: onExpandSidebar
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

    // MARK: - Scroll Content

    private var scrollContent: some View {
        VStack(spacing: 0) {
            if persistentNode != nil {
                pinnedSection
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(workspaces) { workspace in
                        workspaceSection(workspace)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: - Pinned Section

    private var pinnedSection: some View {
        VStack(spacing: 0) {
            condensedRow(
                icon: "dock.rectangle",
                color: tokens.textMuted,
                tooltip: "Docked",
                isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .workspace(AppModel.persistentWorkspaceID),
                action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        persistentSidebarCollapsed.toggle()
                    }
                }
            )
            .contextMenu {
                Button("New Pane") { onNewPersistentPane?() }
            }

            if !persistentSidebarCollapsed, let node = persistentNode {
                let panes = node.allPanes()
                let canClose = panes.count > 1
                ForEach(panes) { pane in
                    paneRow(
                        pane: pane,
                        isFocused: persistentFocusedPaneID == pane.id,
                        isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .pane(pane.id),
                        action: { onSelectPersistentPane?(pane.id) }
                    )
                    .contextMenu {
                        Button("Rename Pane") {
                            editingPaneName = pane.displayName
                            renamePaneTargetID = pane.id
                            showRenamePaneAlert = true
                        }
                        if canClose {
                            Button("Close Pane") { onRemovePersistentPane?(pane.id) }
                        }
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

            Rectangle()
                .fill(Color(tokens.border))
                .frame(height: 1)
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
    }

    private func workspaceRow(workspace: Workspace, isActive: Bool, isCollapsed: Bool) -> some View {
        WorkspaceRailRow(
            workspace: workspace,
            isActive: isActive,
            isCollapsed: isCollapsed,
            isCursorTarget: sidebarHasFocus && sidebarCursorTarget == .workspace(workspace.id),
            tokens: tokens,
            onSelect: { selectedWorkspaceID = workspace.id }
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
                        if let onMoveToPinned = onMovePaneToPinned {
                            Button("Move to Docked") {
                                onMoveToPinned(pane.id)
                            }
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
            if let pane = persistentNode?.findPane(id: targetID) {
                pane.customName = trimmed.isEmpty ? nil : trimmed
                onSave()
            }
        }
        renamePaneTargetID = nil
        showRenamePaneAlert = false
    }

    // MARK: - Keyboard Navigation

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
                    onToggleCollapse(id)
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
            if id == AppModel.persistentWorkspaceID {
                withAnimation(.easeInOut(duration: 0.15)) {
                    persistentSidebarCollapsed.toggle()
                }
                return
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
            .railTooltip(tooltip, tokens: tokens, isHovered: isHovered)
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
    var isCursorTarget: Bool = false
    let tokens: DesignTokens
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(systemName: isCollapsed ? "folder" : "folder.fill")
            .font(.system(size: TypeScale.smallSize))
            .foregroundStyle(Color(isActive ? tokens.text : tokens.textMuted))
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                Rectangle().fill(isCursorTarget ? Color(tokens.elementHover) : Color.clear)
            )
            .railTooltip(workspace.name, tokens: tokens, isHovered: isHovered)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
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

// MARK: - Pane Rail Row

private struct PaneRailRow: View {
    let pane: Pane
    let isFocused: Bool
    var isCursorTarget: Bool = false
    let tokens: DesignTokens
    let action: () -> Void

    @State private var isHovered = false

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
        .railTooltip(pane.displayName, tokens: tokens, isHovered: isHovered)
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

    private var icon: String {
        if pane.attentionKind == .done {
            "checkmark.circle"
        } else if pane.attentionKind == .bell {
            "bell"
        } else if pane.isThinking {
            "arrow.2.circlepath"
        } else if pane.claudeSessionID != nil {
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
        } else if pane.attentionKind != nil {
            Rectangle().fill(Color(tokens.attentionColor(for: pane.attentionKind!)).opacity(0.20))
        } else if pane.isThinking {
            Rectangle().fill(Color(tokens.statusThinking).opacity(0.20))
        } else if pane.isFlagged {
            Rectangle().fill(Color(tokens.statusWarning).opacity(0.15))
        }
    }
}

// MARK: - Rail Tooltip

private struct RailTooltipModifier: ViewModifier {
    let text: String
    let tokens: DesignTokens
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .trailing) {
                if isHovered {
                    Text(text)
                        .font(.system(size: TypeScale.captionSize))
                        .foregroundStyle(Color(tokens.text))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                                .fill(Color(tokens.surfaceHighlight))
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        )
                        .fixedSize()
                        .offset(x: Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
    }
}

private extension View {
    func railTooltip(_ text: String, tokens: DesignTokens, isHovered: Bool) -> some View {
        modifier(RailTooltipModifier(text: text, tokens: tokens, isHovered: isHovered))
    }
}
