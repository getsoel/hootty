# Persistent Panel Pane Movement

## Overview

Move panes between workspaces and the persistent panel via commands, context menus, and drag-and-drop.

## Move via Command

### Workspace to Persistent Panel

- The "Move Pane to Pinned" command MUST remove the focused pane from the workspace's split tree and add it to the persistent panel.
- The pane's ghostty surface MUST be preserved (not destroyed and recreated). The `Pane` object identity and its associated `TerminalSurfaceView` cache entry MUST survive the move.
- After removal from the workspace, if the workspace has remaining panes, focus MUST move to an adjacent workspace pane.
- After removal from the workspace, if the workspace has no remaining panes, a new default pane MUST be created in the workspace.
- The moved pane MUST be added to the persistent node as a vertical split (appended to the last position).
- If `persistentNode` is `nil`, the moved pane MUST become the root leaf node.
- `persistentPanelVisible` MUST be set to `true`.
- `focusDomain` MUST switch to `.persistent`.
- `persistentFocusedPaneID` MUST be set to the moved pane's ID.

### Persistent Panel to Workspace

- The "Move Pane to Workspace" command MUST remove the focused pane from the persistent panel and add it to the selected workspace's split tree.
- The pane's ghostty surface MUST be preserved.
- After removal from the persistent panel, if it has remaining panes, `persistentFocusedPaneID` MUST update to an adjacent pane.
- After removal, if the persistent panel has no remaining panes, `persistentNode` MUST be set to `nil` and `persistentPanelVisible` MUST be set to `false`.
- The pane MUST be added to the workspace's split tree as a split on the focused pane (vertical split, appended).
- `focusDomain` MUST switch to `.workspace`.
- The workspace's `focusedPaneID` MUST be set to the moved pane's ID.

## Move via Context Menu

- Persistent pane rows in the sidebar MUST include a "Move to Workspace" context menu item.
- The context menu item SHOULD present a submenu listing all available workspaces by name.
- Selecting a workspace MUST move the pane to that workspace (same behavior as the command, but targeting a specific workspace instead of the selected one).
- Workspace pane rows MUST include a "Move to Pinned" context menu item.
- The "Move to Pinned" item MUST move the pane to the persistent panel.

## Move via Drag-and-Drop

- Pane rows in the sidebar MAY support drag-and-drop between the persistent section and workspace sections.
- Dragging a persistent pane row onto a workspace row SHOULD move the pane to that workspace.
- Dragging a workspace pane row onto the persistent pseudo-workspace row SHOULD move the pane to the persistent panel.
- The drag data MUST use the existing `paneID.uuidString` transferable format.
- Drop targets MUST validate that the dragged pane is not already in the target location.

## Surface Preservation

- Moving a pane MUST NOT call `ghostty_surface_free` or `removeCachedSurfaceView`.
- The `TerminalSurfaceView` cache in `GhosttyApp` is keyed by pane ID. Since the pane ID does not change, the cached surface view MUST continue to be found after the move.
- The terminal session (PTY, running process) MUST continue uninterrupted through the move.

## Persistence

- After any pane movement, `appModel.saveWorkspaces()` MUST be called to persist the new layout.

## Edge Cases

- Moving the only pane from a workspace MUST create a new default pane in the workspace (workspace invariant: always has at least one pane).
- Moving the only pane from the persistent panel MUST nil out `persistentNode` and hide the panel.
- Moving a pane to itself (same location) MUST be a no-op.
- A pane with in-flight attention state (thinking, bell, done) MUST retain that state through the move.
