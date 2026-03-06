import SwiftUI
import HoottyCore
import LucideIcons

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let tokens: DesignTokens
    let flavor: CatppuccinFlavor
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onSelectPaneGroup: (UUID, UUID) -> Void
    var onSelectPane: (UUID, UUID) -> Void
    var onRemovePaneGroup: (UUID, UUID) -> Void
    var onRemovePane: (UUID, UUID) -> Void
    var onSave: (() -> Void)?
    var sidebarWidth: CGFloat

    @State private var expandedWorkspaceIDs: Set<UUID> = []
    @State private var hoveredWorkspaceID: UUID?
    @State private var hoveredGroupID: UUID?
    @State private var hoveredPaneID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renameGroupTargetID: UUID?
    @State private var editingGroupName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            workspaceList

            Spacer(minLength: 0)

            // Divider
            Rectangle()
                .fill(Color(tokens.border))
                .frame(height: 1)

            addWorkspaceButton
        }
        .frame(width: sidebarWidth)
        .background(Color(tokens.surfaceLow))
        .onAppear {
            if let id = selectedWorkspaceID {
                expandedWorkspaceIDs.insert(id)
            }
        }
        .onChange(of: selectedWorkspaceID) { _, newID in
            if let id = newID {
                expandedWorkspaceIDs.insert(id)
            }
        }
        .alert("Rename Workspace", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Workspace name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Rename Group", isPresented: Binding(
            get: { renameGroupTargetID != nil },
            set: { if !$0 { renameGroupTargetID = nil } }
        )) {
            TextField("Group name", text: $editingGroupName)
            Button("OK") { commitGroupRename() }
            Button("Cancel", role: .cancel) { renameGroupTargetID = nil }
        }
    }

    private var workspaceList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(workspaces) { workspace in
                    workspaceRow(workspace)

                    if expandedWorkspaceIDs.contains(workspace.id) {
                        let groups = workspace.allPaneGroups
                        ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                            let isLastGroup = groupIndex == groups.count - 1
                            if group.panes.count == 1, let pane = group.panes.first {
                                singlePaneGroupRow(
                                    pane: pane,
                                    group: group,
                                    workspace: workspace
                                )
                            } else {
                                groupRow(
                                    group,
                                    workspace: workspace
                                )

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
        }
    }

    private var addWorkspaceButton: some View {
        Button(action: onAddWorkspace) {
            HStack {
                LucideIcon(Lucide.plus, size: TypeScale.smallSize)
                Text("New Workspace")
                    .font(.system(size: TypeScale.smallSize))
            }
            .foregroundStyle(Color(tokens.textMuted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
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

    private func commitGroupRename() {
        let trimmed = editingGroupName.trimmingCharacters(in: .whitespaces)
        if let targetID = renameGroupTargetID {
            for workspace in workspaces {
                if let group = workspace.allPaneGroups.first(where: { $0.id == targetID }) {
                    group.customName = trimmed.isEmpty ? nil : trimmed
                    onSave?()
                    break
                }
            }
        }
        renameGroupTargetID = nil
    }

    // MARK: - Workspace row (depth 0, no tree lines)

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isSelected = workspace.id == selectedWorkspaceID
        let isHovered = workspace.id == hoveredWorkspaceID
        let isExpanded = expandedWorkspaceIDs.contains(workspace.id)
        return HStack(spacing: 6) {
            iconView(name: isExpanded ? "_root_open" : "_root", size: TypeScale.iconSize, needsAttention: workspace.hasAttentionGroup)

            Text(workspace.name)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                onRemoveWorkspace(workspace.id)
            } label: {
                LucideIcon(Lucide.x, size: 9)
                    .foregroundStyle(Color(tokens.textMuted))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            Rectangle()
                .fill(
                    isSelected
                        ? Color(tokens.elementSelected)
                        : isHovered
                            ? Color(tokens.elementHover)
                            : Color.clear
                )
        )
        .overlay {
            if !isExpanded && workspace.hasAttentionGroup {
                Color.clear
                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.statusWarning), lineWidth: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredWorkspaceID = workspace.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredWorkspaceID = nil
            }
        }
        .onTapGesture {
            selectedWorkspaceID = workspace.id
            expandedWorkspaceIDs.insert(workspace.id)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(workspace.name)
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
        return HStack(spacing: 0) {
            TreeConnectorView(
                depth: 1,
                continuingLevels: [],
                tokens: tokens
            )

            HStack(spacing: 6) {
                iconView(name: "folder_command_open", size: TypeScale.iconSize, needsAttention: group.needsAttention)

                Text(group.displayName)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(isFocusedGroup ? tokens.text : tokens.textMuted))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    onRemovePaneGroup(workspace.id, group.id)
                } label: {
                    LucideIcon(Lucide.x, size: 8)
                        .foregroundStyle(Color(tokens.textMuted))
                }
                .buttonStyle(.plain)
                .opacity(isHovered && workspace.allPaneGroups.count > 1 ? 1 : 0)
            }
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .padding(.leading, Spacing.md)
        .background(
            Rectangle()
                .fill(
                    isFocusedGroup
                        ? Color(tokens.elementSelected)
                        : isHovered
                            ? Color(tokens.elementHover)
                            : Color.clear
                )
        )
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredGroupID = group.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredGroupID = nil
            }
        }
        .onTapGesture {
            onSelectPaneGroup(workspace.id, group.id)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(group.displayName)
        .contextMenu {
            Button("Rename Group") {
                editingGroupName = group.customName ?? group.name
                renameGroupTargetID = group.id
            }
            if workspace.allPaneGroups.count > 1 {
                Button("Close Group") {
                    onRemovePaneGroup(workspace.id, group.id)
                }
            }
        }
    }

    // MARK: - Single-pane group row (depth 1, inlined)

    private func singlePaneGroupRow(pane: Pane, group: PaneGroup, workspace: Workspace) -> some View {
        let isFocusedGroup = group.id == workspace.focusedPaneGroupID && workspace.id == selectedWorkspaceID
        let isFocusedPane = isFocusedGroup && group.selectedPaneID == pane.id
        let isHovered = group.id == hoveredGroupID
        return HStack(spacing: 0) {
            TreeConnectorView(
                depth: 1,
                continuingLevels: [],
                tokens: tokens
            )

            HStack(spacing: 6) {
                iconView(name: "bash", size: TypeScale.iconSize, needsAttention: pane.needsAttention)

                Text(pane.displayName)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(isFocusedGroup ? tokens.text : tokens.textMuted))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    onRemovePaneGroup(workspace.id, group.id)
                } label: {
                    LucideIcon(Lucide.x, size: 8)
                        .foregroundStyle(Color(tokens.textMuted))
                }
                .buttonStyle(.plain)
                .opacity(isHovered && workspace.allPaneGroups.count > 1 ? 1 : 0)
            }
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .padding(.leading, Spacing.md)
        .background(
            Rectangle()
                .fill(
                    isFocusedGroup
                        ? Color(tokens.elementSelected)
                        : isHovered
                            ? Color(tokens.elementHover)
                            : Color.clear
                )
        )
        .overlay {
            if pane.needsAttention {
                Color.clear
                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.statusWarning), lineWidth: 1)
            } else if isFocusedPane {
                Rectangle().stroke(Color(tokens.textAccent), lineWidth: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredGroupID = group.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredGroupID = nil
            }
        }
        .onTapGesture {
            onSelectPaneGroup(workspace.id, group.id)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(pane.displayName)
        .contextMenu {
            if workspace.allPaneGroups.count > 1 {
                Button("Close Pane") {
                    onRemovePaneGroup(workspace.id, group.id)
                }
            }
        }
    }

    // MARK: - Pane row (depth 2)

    private func paneRow(_ pane: Pane, group: PaneGroup, workspace: Workspace, isLastGroup: Bool) -> some View {
        let isFocusedGroup = group.id == workspace.focusedPaneGroupID && workspace.id == selectedWorkspaceID
        let isFocusedPane = isFocusedGroup && group.selectedPaneID == pane.id
        let isHovered = pane.id == hoveredPaneID
        let displayName = pane.displayName

        // If the group is not the last sibling, we need a continuing vertical line at depth 1
        let continuing: Set<Int> = isLastGroup ? [] : [0]

        return HStack(spacing: 0) {
            TreeConnectorView(
                depth: 2,
                continuingLevels: continuing,
                tokens: tokens
            )

            HStack(spacing: 6) {
                iconView(name: "bash", size: TypeScale.iconSize, needsAttention: pane.needsAttention)

                Text(displayName)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(isFocusedGroup ? tokens.text : tokens.textMuted))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    onRemovePane(workspace.id, pane.id)
                } label: {
                    LucideIcon(Lucide.x, size: 7)
                        .foregroundStyle(Color(tokens.textMuted))
                }
                .buttonStyle(.plain)
                .opacity(isHovered && group.panes.count > 1 ? 1 : 0)
            }
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .padding(.leading, Spacing.md)
        .background(
            Rectangle()
                .fill(
                    isFocusedGroup
                        ? Color(tokens.elementSelected)
                        : isHovered
                            ? Color(tokens.elementHover)
                            : Color.clear
                )
        )
        .overlay {
            if pane.needsAttention {
                Color.clear
                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.statusWarning), lineWidth: 1)
            } else if isFocusedPane {
                Rectangle().stroke(Color(tokens.textAccent), lineWidth: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredPaneID = pane.id
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                hoveredPaneID = nil
            }
        }
        .onTapGesture {
            onSelectPane(workspace.id, pane.id)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(displayName)
        .contextMenu {
            if group.panes.count > 1 {
                Button("Close Pane") {
                    onRemovePane(workspace.id, pane.id)
                }
            }
        }
    }

    // MARK: - Helpers

    private func iconView(name: String, size: CGFloat, needsAttention: Bool) -> some View {
        CatppuccinIconView(name: name, size: size, flavor: flavor)
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
    let tokens: DesignTokens

    private let gutterWidth: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let lineColor = Color(tokens.textMuted).opacity(0.3)

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
