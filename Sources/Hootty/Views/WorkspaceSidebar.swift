import SwiftUI
import HoottyCore

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let theme: TerminalTheme
    let flavor: CatppuccinFlavor
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
        .background(Color(theme.mantle))
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
            LazyVStack(spacing: 0) {
                boardRow

                ForEach(workspaces) { workspace in
                    workspaceRow(workspace)

                    if expandedWorkspaceIDs.contains(workspace.id) {
                        let groups = workspace.allPaneGroups
                        ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                            let isLastGroup = groupIndex == groups.count - 1
                            groupRow(
                                group,
                                workspace: workspace
                            )

                            if group.panes.count > 1 {
                                ForEach(group.panes) { pane in
                                    paneRow(
                                        pane,
                                        group: group,
                                        workspace: workspace,
                                        isLastGroup: isLastGroup
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var boardRow: some View {
        HStack(spacing: 6) {
            CatppuccinIconView(
                name: "todo",
                size: 14,
                flavor: flavor,
                templateColor: Color(isKanbanSelected ? theme.foreground : theme.sidebarTextSecondary)
            )

            Text("Board")
                .font(.system(size: 13))
                .foregroundStyle(Color(isKanbanSelected ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Rectangle()
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

    // MARK: - Row icon color

    private func iconColor(needsAttention: Bool, isFocused: Bool, isRunning: Bool) -> Color {
        if needsAttention {
            return Color(theme.attentionColor)
        } else if isFocused {
            return Color(theme.foreground)
        } else if isRunning {
            return Color(theme.sidebarRunningDot)
        } else {
            return Color(theme.sidebarTextSecondary)
        }
    }

    // MARK: - Workspace row (depth 0, no tree lines)

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isSelected = workspace.id == selectedWorkspaceID
        let isHovered = workspace.id == hoveredWorkspaceID
        let isExpanded = expandedWorkspaceIDs.contains(workspace.id)
        let color = iconColor(
            needsAttention: workspace.hasAttentionGroup,
            isFocused: isSelected,
            isRunning: workspace.isRunning
        )
        return HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(theme.sidebarTextSecondary))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
                .frame(width: 10)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpanded(workspace.id)
                }

            iconView(name: "_folder", size: 13, color: color, needsAttention: workspace.hasAttentionGroup)

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
            Rectangle()
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

    // MARK: - Group row (depth 1)

    private func groupRow(_ group: PaneGroup, workspace: Workspace) -> some View {
        let isFocusedGroup = group.id == workspace.focusedPaneGroupID && workspace.id == selectedWorkspaceID
        let isHovered = group.id == hoveredGroupID
        let color = iconColor(
            needsAttention: group.needsAttention,
            isFocused: isFocusedGroup,
            isRunning: group.isRunning
        )
        return HStack(spacing: 0) {
            TreeConnectorView(
                depth: 1,
                continuingLevels: [],
                theme: theme
            )

            HStack(spacing: 6) {
                iconView(name: "_folder_open", size: 13, color: color, needsAttention: group.needsAttention)

                Text(group.displayName)
                    .font(.system(size: 13))
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
            .padding(.trailing, 8)
        }
        .padding(.leading, 8)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(
                    isFocusedGroup
                        ? Color(theme.sidebarSurface)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.4)
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

    // MARK: - Pane row (depth 2)

    private func paneRow(_ pane: Pane, group: PaneGroup, workspace: Workspace, isLastGroup: Bool) -> some View {
        let isFocused = group.id == workspace.focusedPaneGroupID
            && workspace.id == selectedWorkspaceID
            && group.selectedPaneID == pane.id
        let isHovered = pane.id == hoveredPaneID
        let dirName = (pane.workingDirectory as NSString).lastPathComponent
        let color = iconColor(
            needsAttention: pane.needsAttention,
            isFocused: isFocused,
            isRunning: pane.isRunning
        )

        // If the group is not the last sibling, we need a continuing vertical line at depth 1
        let continuing: Set<Int> = isLastGroup ? [] : [1]

        return HStack(spacing: 0) {
            TreeConnectorView(
                depth: 2,
                continuingLevels: continuing,
                theme: theme
            )

            HStack(spacing: 6) {
                iconView(name: "bash", size: 13, color: color, needsAttention: pane.needsAttention)

                Text(dirName)
                    .font(.system(size: 13))
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
            .padding(.trailing, 8)
        }
        .padding(.leading, 8)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(
                    isFocused
                        ? Color(theme.sidebarSurface)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.4)
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

    // MARK: - Helpers

    @ViewBuilder
    private func iconView(name: String, size: CGFloat, color: Color, needsAttention: Bool) -> some View {
        if needsAttention {
            CatppuccinIconView(name: name, size: size, flavor: flavor, templateColor: color)
                .modifier(PulseModifier())
        } else {
            CatppuccinIconView(name: name, size: size, flavor: flavor, templateColor: color)
        }
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedWorkspaceIDs.contains(id) {
            expandedWorkspaceIDs.remove(id)
        } else {
            expandedWorkspaceIDs.insert(id)
        }
    }
}

// MARK: - Tree Connector

private struct TreeConnectorView: View {
    let depth: Int
    let continuingLevels: Set<Int>
    let theme: TerminalTheme

    private let gutterWidth: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let lineColor = Color(theme.sidebarTextSecondary).opacity(0.2)

            // Draw continuing vertical lines for ancestor levels
            for level in continuingLevels {
                let x = CGFloat(level) * gutterWidth + gutterWidth / 2
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            }

            // Draw vertical line at current depth — always full height
            if depth > 0 {
                let x = size.width - gutterWidth / 2
                var verticalPath = Path()
                verticalPath.move(to: CGPoint(x: x, y: 0))
                verticalPath.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(verticalPath, with: .color(lineColor), lineWidth: 1)
            }
        }
        .frame(width: CGFloat(depth) * gutterWidth)
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
