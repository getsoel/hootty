import Foundation
import HoottyCore

/// Encapsulates keyboard navigation logic for the workspace sidebar.
/// Manages cursor position across all navigable panes in all workspaces.
@MainActor
struct SidebarKeyboardNav {
    /// All navigable items in tree order across all workspaces.
    static func allNavigableItems(workspaces: [Workspace]) -> [(workspaceID: UUID, paneID: UUID)] {
        workspaces.flatMap { ws in
            ws.allPanes.map { (ws.id, $0.id) }
        }
    }

    /// Move the cursor up or down by one position. Clamps to bounds.
    static func moveCursor(
        direction: Int,
        workspaces: [Workspace],
        selectedWorkspaceID: UUID?,
        currentCursorPaneID: UUID?
    ) -> UUID? {
        let items = allNavigableItems(workspaces: workspaces)
        guard !items.isEmpty else { return nil }

        let selectedWorkspace = workspaces.first { $0.id == selectedWorkspaceID }
        let currentID = currentCursorPaneID ?? selectedWorkspace?.focusedPaneID

        guard let currentID,
              let idx = items.firstIndex(where: { $0.paneID == currentID })
        else {
            return items.first?.paneID
        }

        let newIdx = idx + direction
        guard newIdx >= 0, newIdx < items.count else { return currentID }
        return items[newIdx].paneID
    }

    /// Resolve cursor selection: returns the (workspaceID, paneID) for the current cursor.
    static func confirmCursor(
        cursorPaneID: UUID?,
        workspaces: [Workspace]
    ) -> (workspaceID: UUID, paneID: UUID)? {
        guard let cursorID = cursorPaneID else { return nil }
        let items = allNavigableItems(workspaces: workspaces)
        return items.first { $0.paneID == cursorID }
    }
}
