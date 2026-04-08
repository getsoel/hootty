import Foundation

/// Identifies what the sidebar keyboard cursor is targeting.
public enum SidebarCursorTarget: Equatable, Sendable {
    case workspace(UUID)
    case pane(UUID)

    /// Extract the pane ID if the cursor targets a pane, nil for workspace targets.
    public var cursorPaneID: UUID? {
        if case let .pane(id) = self { return id }
        return nil
    }
}

/// A navigable item in the sidebar list (workspace row or pane row).
public enum SidebarNavItem: Equatable, Sendable {
    case workspace(UUID)
    case pane(workspaceID: UUID, paneID: UUID)
}

/// Encapsulates keyboard navigation logic for the workspace sidebar.
/// Manages cursor position across all navigable items (workspace rows and pane rows).
@MainActor
public enum SidebarKeyboardNav {
    /// All navigable items in tree order across all workspaces.
    /// Workspace rows are always included. Pane rows are excluded for effectively collapsed workspaces
    /// and for panes that don't match active sidebar filters (the focused pane of the selected workspace is always included).
    public static func allNavigableItems(
        workspaces: [Workspace],
        collapsedWorkspaceIDs: Set<UUID>,
        selectedWorkspaceID: UUID?,
        activeFilters: Set<SidebarFilter> = []
    ) -> [SidebarNavItem] {
        var items: [SidebarNavItem] = []

        for ws in workspaces {
            items.append(.workspace(ws.id))
            let effectivelyCollapsed = collapsedWorkspaceIDs.contains(ws.id)
            if !effectivelyCollapsed {
                let isSelectedWs = ws.id == selectedWorkspaceID
                for pane in ws.allPanes where pane.isVisibleInSidebar(isFocusedInSelectedWorkspace: isSelectedWs && pane.id == ws.focusedPaneID, filters: activeFilters) {
                    items.append(.pane(workspaceID: ws.id, paneID: pane.id))
                }
            }
        }
        return items
    }

    /// Move the cursor up or down by one position. Clamps to bounds.
    public static func moveCursor(
        direction: Int,
        workspaces: [Workspace],
        collapsedWorkspaceIDs: Set<UUID>,
        selectedWorkspaceID: UUID?,
        currentTarget: SidebarCursorTarget?,
        activeFilters: Set<SidebarFilter> = []
    ) -> SidebarCursorTarget? {
        let items = allNavigableItems(
            workspaces: workspaces,
            collapsedWorkspaceIDs: collapsedWorkspaceIDs,
            selectedWorkspaceID: selectedWorkspaceID,
            activeFilters: activeFilters
        )
        guard !items.isEmpty else { return nil }

        let currentIdx: Int? = currentTarget.flatMap { target in
            switch target {
            case let .workspace(id):
                items.firstIndex(of: .workspace(id))
            case let .pane(id):
                items.firstIndex(where: {
                    if case let .pane(_, paneID) = $0 { return paneID == id }
                    return false
                })
            }
        }

        guard let idx = currentIdx else {
            return navItemToTarget(items.first)
        }

        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < items.count else {
            return navItemToTarget(items[idx])
        }
        return navItemToTarget(items[newIdx])
    }

    /// Resolve cursor selection: returns the nav item for the current cursor target.
    public static func confirmCursor(
        target: SidebarCursorTarget?,
        workspaces: [Workspace],
        collapsedWorkspaceIDs: Set<UUID>,
        selectedWorkspaceID: UUID?
    ) -> SidebarNavItem? {
        guard let target else { return nil }
        let items = allNavigableItems(
            workspaces: workspaces,
            collapsedWorkspaceIDs: collapsedWorkspaceIDs,
            selectedWorkspaceID: selectedWorkspaceID
        )
        switch target {
        case let .workspace(id):
            return items.first { $0 == .workspace(id) }
        case let .pane(id):
            return items.first {
                if case let .pane(_, paneID) = $0 { return paneID == id }
                return false
            }
        }
    }

    /// Find the workspace ID that owns a given pane.
    public static func workspaceForPane(
        paneID: UUID,
        workspaces: [Workspace]
    ) -> UUID? {
        for ws in workspaces where ws.findPane(id: paneID) != nil {
            return ws.id
        }
        return nil
    }

    // MARK: - Private

    private static func navItemToTarget(_ item: SidebarNavItem?) -> SidebarCursorTarget? {
        guard let item else { return nil }
        switch item {
        case let .workspace(id): return .workspace(id)
        case let .pane(_, paneID): return .pane(paneID)
        }
    }
}
