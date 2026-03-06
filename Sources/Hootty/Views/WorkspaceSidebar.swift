import SwiftUI
import HoottyCore

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let theme: TerminalTheme
    let isKanbanSelected: Bool
    var onSelectKanban: () -> Void
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onSelectPaneGroup: (UUID, UUID) -> Void
    var onSelectPane: (UUID, UUID) -> Void
    var onRemovePaneGroup: (UUID, UUID) -> Void
    var onRemovePane: (UUID, UUID) -> Void
    var onSave: (() -> Void)?
    var sidebarWidth: CGFloat

    @State private var expandedWorkspaceIDs: Set<UUID> = []
    @State private var hoveredBoardRow = false
    @State private var hoveredWorkspaceID: UUID?
    @State private var hoveredGroupID: UUID?
    @State private var hoveredPaneID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            workspaceList

            Spacer(minLength: 0)

            // Divider
            Rectangle()
                .fill(Color(theme.sidebarSurface))
                .frame(height: 1)

            addWorkspaceButton
        }
        .frame(width: sidebarWidth)
        .background(Color(theme.background))
        .alert("Rename Workspace", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Workspace name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
    }

    private var workspaceList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                boardRow

                ForEach(workspaces) { workspace in
                    workspaceRow(workspace)

                    if expandedWorkspaceIDs.contains(workspace.id) {
                        ForEach(workspace.allPaneGroups) { group in
                            groupRow(group, workspace: workspace)

                            if group.panes.count > 1 {
                                ForEach(group.panes) { pane in
                                    paneRow(pane, group: group, workspace: workspace)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
    }

    private var boardRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(isKanbanSelected ? theme.foreground : theme.sidebarTextSecondary))
                .frame(width: 12)

            Text("Board")
                .font(.system(size: 13))
                .foregroundStyle(Color(isKanbanSelected ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isKanbanSelected
                        ? Color(theme.sidebarSurface)
                        : hoveredBoardRow
                            ? Color(theme.sidebarSurface).opacity(0.4)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredBoardRow = hovering
        }
        .onTapGesture {
            onSelectKanban()
        }
    }

    private var addWorkspaceButton: some View {
        Button(action: onAddWorkspace) {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("New Workspace")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color(theme.sidebarTextSecondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isSelected = workspace.id == selectedWorkspaceID
        let isHovered = workspace.id == hoveredWorkspaceID
        let isExpanded = expandedWorkspaceIDs.contains(workspace.id)
        return HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(theme.sidebarTextSecondary))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
                .frame(width: 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpanded(workspace.id)
                }

            workspaceStatusDot(workspace)
                .frame(width: 7, height: 7)

            Text(workspace.name)
                .font(.system(size: 13))
                .foregroundStyle(Color(isSelected ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isHovered {
                Button {
                    onRemoveWorkspace(workspace.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(theme.sidebarTextSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color(theme.sidebarSurface)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.4)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredWorkspaceID = hovering ? workspace.id : nil
        }
        .onTapGesture {
            selectedWorkspaceID = workspace.id
            expandedWorkspaceIDs.insert(workspace.id)
        }
        .contextMenu {
            Button("Rename Workspace") {
                editingName = workspace.name
                renameTargetID = workspace.id
            }
        }
    }

    private func groupRow(_ group: PaneGroup, workspace: Workspace) -> some View {
        let isFocusedGroup = group.id == workspace.focusedPaneGroupID && workspace.id == selectedWorkspaceID
        let isHovered = group.id == hoveredGroupID
        return HStack(spacing: 6) {
            groupStatusDot(group)
                .frame(width: 6, height: 6)

            Text(group.displayName)
                .font(.system(size: 12))
                .foregroundStyle(Color(isFocusedGroup ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isHovered && workspace.allPaneGroups.count > 1 {
                Button {
                    onRemovePaneGroup(workspace.id, group.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(theme.sidebarTextSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 32)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isFocusedGroup
                        ? Color(theme.sidebarSurface).opacity(0.7)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.3)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredGroupID = hovering ? group.id : nil
        }
        .onTapGesture {
            onSelectPaneGroup(workspace.id, group.id)
        }
        .contextMenu {
            if workspace.allPaneGroups.count > 1 {
                Button("Close Group") {
                    onRemovePaneGroup(workspace.id, group.id)
                }
            }
        }
    }

    private func paneRow(_ pane: Pane, group: PaneGroup, workspace: Workspace) -> some View {
        let isFocused = group.id == workspace.focusedPaneGroupID
            && workspace.id == selectedWorkspaceID
            && group.selectedPaneID == pane.id
        let isHovered = pane.id == hoveredPaneID
        let dirName = (pane.workingDirectory as NSString).lastPathComponent

        return HStack(spacing: 6) {
            paneStatusDot(pane)
                .frame(width: 5, height: 5)

            Text(dirName)
                .font(.system(size: 11))
                .foregroundStyle(Color(isFocused ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isHovered && group.panes.count > 1 {
                Button {
                    onRemovePane(workspace.id, pane.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color(theme.sidebarTextSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 48)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isFocused
                        ? Color(theme.sidebarSurface).opacity(0.5)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.2)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredPaneID = hovering ? pane.id : nil
        }
        .onTapGesture {
            onSelectPane(workspace.id, pane.id)
        }
        .contextMenu {
            if group.panes.count > 1 {
                Button("Close Pane") {
                    onRemovePane(workspace.id, pane.id)
                }
            }
        }
    }

    private func paneStatusDot(_ pane: Pane) -> some View {
        StatusDotView(needsAttention: pane.needsAttention, isRunning: pane.isRunning, theme: theme)
    }

    private func groupStatusDot(_ group: PaneGroup) -> some View {
        StatusDotView(needsAttention: group.needsAttention, isRunning: group.isRunning, theme: theme)
    }

    private func workspaceStatusDot(_ workspace: Workspace) -> some View {
        StatusDotView(needsAttention: workspace.hasAttentionGroup, isRunning: workspace.isRunning, theme: theme)
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedWorkspaceIDs.contains(id) {
            expandedWorkspaceIDs.remove(id)
        } else {
            expandedWorkspaceIDs.insert(id)
        }
    }
}

struct StatusDotView: View {
    let needsAttention: Bool
    let isRunning: Bool
    let theme: TerminalTheme

    var body: some View {
        if needsAttention {
            Circle()
                .fill(Color(theme.attentionColor))
                .modifier(PulseModifier())
        } else {
            Circle()
                .fill(Color(isRunning ? theme.sidebarRunningDot : theme.sidebarStoppedDot))
        }
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.4)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
