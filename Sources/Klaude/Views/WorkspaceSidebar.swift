import SwiftUI
import KlaudeCore

struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: UUID?
    let theme: TerminalTheme
    var onAddWorkspace: () -> Void
    var onRemoveWorkspace: (UUID) -> Void
    var onSelectTab: (UUID, UUID) -> Void
    var onAddTab: (UUID) -> Void
    var onRemoveTab: (UUID, UUID) -> Void

    @State private var expandedWorkspaceIDs: Set<UUID> = []
    @State private var hoveredWorkspaceID: UUID?
    @State private var hoveredTabID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var renameTabTargetID: UUID?
    @State private var renameTabWorkspaceID: UUID?
    @State private var editingTabName: String = ""

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
        .frame(width: 200)
        .background(Color(theme.background))
        .alert("Rename Workspace", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Workspace name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Rename Tab", isPresented: Binding(
            get: { renameTabTargetID != nil },
            set: { if !$0 { renameTabTargetID = nil; renameTabWorkspaceID = nil } }
        )) {
            TextField("Tab name", text: $editingTabName)
            Button("OK") { commitTabRename() }
            Button("Cancel", role: .cancel) { renameTabTargetID = nil; renameTabWorkspaceID = nil }
        }
    }

    private var workspaceList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(workspaces) { workspace in
                    workspaceRow(workspace)

                    if expandedWorkspaceIDs.contains(workspace.id) {
                        ForEach(workspace.tabs) { tab in
                            tabRow(tab, workspace: workspace)
                        }

                        addTabButton(workspaceID: workspace.id)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
    }

    private func addTabButton(workspaceID: UUID) -> some View {
        Button {
            onAddTab(workspaceID)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .medium))
                Text("New Tab")
                    .font(.system(size: 11))
            }
            .foregroundStyle(Color(theme.sidebarTextSecondary))
            .padding(.leading, 32)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
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
        }
        renameTargetID = nil
    }

    private func workspaceRow(_ workspace: Workspace) -> some View {
        let isSelected = workspace.id == selectedWorkspaceID
        let isHovered = workspace.id == hoveredWorkspaceID
        let isExpanded = expandedWorkspaceIDs.contains(workspace.id)
        return HStack(spacing: 6) {
            // Disclosure chevron
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

            Circle()
                .fill(Color(workspace.isRunning ? theme.sidebarRunningDot : theme.sidebarStoppedDot))
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
            Divider()
            Button("New Tab") {
                onAddTab(workspace.id)
            }
        }
    }

    private func tabRow(_ tab: KlaudeCore.Tab, workspace: Workspace) -> some View {
        let isSelectedTab = tab.id == workspace.selectedTabID && workspace.id == selectedWorkspaceID
        let isHovered = tab.id == hoveredTabID
        return HStack(spacing: 6) {
            Circle()
                .fill(Color(tab.isRunning ? theme.sidebarRunningDot : theme.sidebarStoppedDot))
                .frame(width: 6, height: 6)

            Text(tab.name)
                .font(.system(size: 12))
                .foregroundStyle(Color(isSelectedTab ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isHovered && workspace.tabs.count > 1 {
                Button {
                    onRemoveTab(workspace.id, tab.id)
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
                    isSelectedTab
                        ? Color(theme.sidebarSurface).opacity(0.7)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.3)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredTabID = hovering ? tab.id : nil
        }
        .onTapGesture {
            onSelectTab(workspace.id, tab.id)
        }
        .contextMenu {
            Button("Rename Tab") {
                editingTabName = tab.name
                renameTabTargetID = tab.id
                renameTabWorkspaceID = workspace.id
            }
            if workspace.tabs.count > 1 {
                Divider()
                Button("Close Tab") {
                    onRemoveTab(workspace.id, tab.id)
                }
            }
        }
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedWorkspaceIDs.contains(id) {
            expandedWorkspaceIDs.remove(id)
        } else {
            expandedWorkspaceIDs.insert(id)
        }
    }

    private func commitTabRename() {
        let trimmed = editingTabName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty,
           let workspace = workspaces.first(where: { $0.id == renameTabWorkspaceID }),
           let tab = workspace.tabs.first(where: { $0.id == renameTabTargetID }) {
            tab.name = trimmed
        }
        renameTabTargetID = nil
        renameTabWorkspaceID = nil
    }
}
