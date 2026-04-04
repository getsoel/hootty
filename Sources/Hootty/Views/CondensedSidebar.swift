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
        .contextMenu {
            Button("New Workspace") { onAddWorkspace() }
            if persistentNode != nil {
                Button("New Pinned Pane") { onNewPersistentPane?() }
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
        ScrollView {
            VStack(spacing: 0) {
                if persistentNode != nil {
                    pinnedSection
                }
                ForEach(workspaces) { workspace in
                    workspaceSection(workspace)
                }
            }
        }
        .scrollIndicators(.never)
    }

    // MARK: - Pinned Section

    private var pinnedSection: some View {
        VStack(spacing: 0) {
            condensedRow(
                icon: "pin.fill",
                color: tokens.textMuted,
                tooltip: "Pinned",
                isSelected: false,
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
        let summary: WorkspaceAttentionSummary? = isCollapsed ? attentionSummary(for: workspace.allPanes) : nil

        return HStack(spacing: 0) {
            ZStack {
                Image(systemName: isCollapsed ? "folder.fill" : "folder")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(isActive ? tokens.text : tokens.textMuted))

                if let summary {
                    attentionBadge(summary: summary)
                        .offset(x: 6, y: -5)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .help(workspace.name)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedWorkspaceID = workspace.id
        }
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
                        action: { onSelectPane(workspace.id, pane.id) }
                    )
                    .contextMenu {
                        Button("Rename Pane") {
                            editingPaneName = pane.displayName
                            renamePaneTargetID = pane.id
                            showRenamePaneAlert = true
                        }
                        if let onMoveToPinned = onMovePaneToPinned {
                            Button("Move to Pinned") {
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
        let iconName: String = if section.branch == nil {
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
            isSelected: false,
            action: {}
        )
    }

    // MARK: - Pane Row

    private func paneRow(pane: Pane, isFocused: Bool, action: @escaping () -> Void) -> some View {
        let (icon, color) = paneIconAndColor(pane: pane, isFocused: isFocused)

        return Group {
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
        .background(paneBackground(pane: pane, isFocused: isFocused))
        .help(pane.displayName)
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .onContinuousHover { phase in
            if case .active = phase {
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            }
        }
    }

    private func paneIconAndColor(pane: Pane, isFocused: Bool) -> (String, NSColor) {
        if pane.attentionKind == .done {
            return ("checkmark.circle", tokens.statusDone)
        } else if pane.attentionKind == .bell {
            return ("bell", tokens.statusBell)
        } else if pane.isThinking {
            return ("arrow.2.circlepath", tokens.statusThinking)
        } else if pane.claudeSessionID != nil {
            return ("bubble.left.fill", isFocused ? tokens.text : tokens.textMuted)
        } else {
            return ("apple.terminal", isFocused ? tokens.text : tokens.textMuted)
        }
    }

    @ViewBuilder
    private func paneBackground(pane: Pane, isFocused: Bool) -> some View {
        if isFocused {
            Rectangle().fill(Color(tokens.elementSelected))
        } else if pane.attentionKind != nil {
            Rectangle().fill(Color(tokens.attentionColor(for: pane.attentionKind!)).opacity(0.20))
        } else if pane.isThinking {
            Rectangle().fill(Color(tokens.statusThinking).opacity(0.20))
        } else if pane.isFlagged {
            Rectangle().fill(Color(tokens.statusWarning).opacity(0.15))
        }
    }

    // MARK: - Shared Row

    private func condensedRow(
        icon: String,
        color: NSColor,
        tooltip: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        CondensedRowView(
            icon: icon,
            color: color,
            tooltip: tooltip,
            isSelected: isSelected,
            tokens: tokens,
            action: action
        )
    }

    // MARK: - Attention

    private func attentionSummary(for panes: [Pane]) -> WorkspaceAttentionSummary? {
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

    @ViewBuilder
    private func attentionBadge(summary: WorkspaceAttentionSummary) -> some View {
        let color: NSColor = switch summary {
        case .thinking: tokens.statusThinking
        case .done: tokens.statusDone
        case .bell: tokens.statusBell
        }
        Circle()
            .fill(Color(color))
            .frame(width: 6, height: 6)
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
            // Also check persistent panes
            if let pane = persistentNode?.findPane(id: targetID) {
                pane.customName = trimmed.isEmpty ? nil : trimmed
                onSave()
            }
        }
        renamePaneTargetID = nil
        showRenamePaneAlert = false
    }
}

// MARK: - Condensed Row View

private struct CondensedRowView: View {
    let icon: String
    let color: NSColor
    let tooltip: String
    let isSelected: Bool
    let tokens: DesignTokens
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: TypeScale.smallSize))
            .foregroundStyle(Color(color))
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(
                Rectangle().fill(isHovered ? Color(tokens.elementHover) : Color.clear)
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
