# Sidebar Keyboard Navigation: Workspace Rows

## Overview

Extend sidebar keyboard navigation so the cursor can land on workspace rows (not just pane rows), enabling keyboard-driven collapse/expand via left/right arrow keys.

## Cursor Target Type

- ADDED: A `SidebarCursorTarget` enum with cases `.workspace(UUID)` and `.pane(UUID)`.
- MODIFIED: The sidebar cursor state MUST use `SidebarCursorTarget?` instead of `UUID?` (currently `sidebarCursorPaneID`).
- The cursor target MUST be threaded through `WorkspaceSidebar`, `ContentView`, and the SwiftUI environment.

## Navigable Items

- MODIFIED: `SidebarKeyboardNav.allNavigableItems` MUST return an array of `SidebarNavItem` (enum with `.workspace(UUID)` and `.pane(workspaceID: UUID, paneID: UUID)` cases).
- Workspace rows MUST appear as navigable items in the list.
- Pane rows for effectively collapsed workspaces MUST be excluded from the navigable list.
- Pane rows for expanded workspaces MUST appear after their workspace row, preserving tree order.
- The navigable list order MUST be: `[workspace1, pane1a, pane1b, workspace2, pane2a, ...]`.

## Up/Down Navigation

- Up/down arrow keys MUST move the cursor sequentially through the navigable item list (workspace and pane rows).
- The cursor MUST clamp at list boundaries (no wrapping).
- When entering sidebar focus mode, the cursor MUST start on the focused pane of the selected workspace (existing behavior, but now returns `.pane(...)` instead of a bare UUID).

## Left/Right Navigation

- Left arrow on a workspace row MUST collapse the workspace (add to `collapsedWorkspaceIDs`).
- Right arrow on a workspace row MUST expand the workspace (remove from `collapsedWorkspaceIDs`).
- Left arrow on an already-collapsed workspace row MUST be a no-op.
- Right arrow on an already-expanded workspace row MUST be a no-op.
- Left arrow on a pane row MUST move the cursor to the parent workspace row.
- Right arrow on a pane row SHOULD be a no-op.

## Enter/Confirm

- Enter on a workspace row MUST select the workspace (set `selectedWorkspaceID`, same as clicking the row).
- Enter on a pane row MUST select and focus the pane (existing behavior).

## Cursor Highlight

- `WorkspaceRow` MUST show a cursor highlight (matching `SidebarPaneRow`'s `isCursorTarget` styling) when the keyboard cursor targets it.
- The highlight MUST use `tokens.borderFocused` as an overlay border, consistent with the existing pane row cursor style.

## Collapse Side Effects on Cursor

- When a workspace is collapsed via left arrow and the cursor was on the workspace row, the cursor MUST remain on the workspace row.
- When a workspace is collapsed via context menu or command while pane rows within it are visible, the cursor position MAY remain unchanged (collapsed panes are simply removed from the navigable list; cursor clamps on next move).

## Environment Propagation

- MODIFIED: The `sidebarCursorPaneID` environment key MUST be replaced (or supplemented) with a mechanism that `SplitNodeView` can use to determine if a specific pane is the cursor target.
- `SidebarPaneRow` MUST continue to highlight when the cursor targets it.
- `WorkspaceRow` MUST highlight when the cursor targets it.
