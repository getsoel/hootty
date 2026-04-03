# Workspace Collapse

## Overview

Allow workspace folders in the sidebar to be collapsed (hiding their pane list) or expanded (showing it). The selected workspace is always expanded regardless of collapse state.

## Model

- `AppModel` MUST expose a `collapsedWorkspaceIDs: Set<UUID>` property tracking which workspaces are collapsed.
- `AppModel` MUST provide `toggleWorkspaceCollapse(_ id: UUID)` to add/remove from the set.
- `AppModel` MUST provide `collapseAllWorkspaces()` that adds all workspace IDs to the set.
- `AppModel` MUST provide `expandAllWorkspaces()` that clears the set.
- When a workspace is removed, its ID SHOULD be cleaned from `collapsedWorkspaceIDs`.

## Effective Collapse State

- A workspace MUST be treated as visually collapsed only when it is in `collapsedWorkspaceIDs` AND it is NOT the `selectedWorkspaceID`.
- The selected (focused) workspace MUST always render its pane list, even if its ID is in `collapsedWorkspaceIDs`.
- Selecting a collapsed workspace MUST visually expand it (without removing it from the collapsed set), so switching away collapses it again.

## Persistence

- `WorkspaceSnapshot` MUST include an optional `collapsedWorkspaceIDs: Set<UUID>?` field.
- On decode, if the field is absent or nil, `collapsedWorkspaceIDs` MUST default to an empty set (backward-compatible).
- `AppModel.saveWorkspaces()` MUST include `collapsedWorkspaceIDs` in the snapshot.

## Sidebar Rendering

- When a workspace is effectively collapsed, `WorkspaceSidebar` MUST NOT render `workspacePaneList` for that workspace.
- When a workspace is effectively expanded, `WorkspaceSidebar` MUST render `workspacePaneList` as it does today.
- The pane list show/hide SHOULD animate with a vertical slide transition.

## Workspace Row Icon

- `WorkspaceRow` MUST display `folder.fill` (SF Symbol) when the workspace is effectively collapsed.
- `WorkspaceRow` MUST display `folder.open.fill` (SF Symbol) when the workspace is effectively expanded.
- Clicking the workspace row MUST select the workspace (existing behavior, unchanged).

## Attention Summary on Collapsed Row

- When a workspace is effectively collapsed, its `WorkspaceRow` MUST display a `StatusDotView` summarizing the highest-priority attention state of its child panes.
- Priority order: thinking > done > bell (thinking is most urgent, then attention kinds).
- The status dot MUST use the same color tokens as `SidebarPaneRow` status dots (`statusThinking`, `statusDone`, `statusBell`).
- The status dot SHOULD appear between the folder icon and the workspace name.
- When no child pane has attention or is thinking, the status dot MUST NOT be shown.
- When a workspace is effectively expanded, the status dot MUST NOT be shown (individual pane rows handle it).

## Context Menu

- `WorkspaceRow` context menu MUST include a "Collapse" item when the workspace is expanded and not selected.
- `WorkspaceRow` context menu MUST include an "Expand" item when the workspace is collapsed.
- For the selected workspace, the context menu MAY omit the collapse/expand item (since it's always visually expanded).

## Commands

- `AppCommand` MUST include a `collapseAllWorkspaces` case with title "Collapse All Workspaces".
- `AppCommand` MUST include an `expandAllWorkspaces` case with title "Expand All Workspaces".
- Both commands MUST appear in the command palette.
- Both commands MAY have no keyboard shortcut.

## Scroll Targets

- MODIFIED: `WorkspaceSidebar.scrollTargetIDs` MUST exclude pane IDs for effectively collapsed workspaces. Workspace row IDs MUST still be included.

## Auto-Scroll on Focus

- MODIFIED: When `selectedWorkspace.focusedPaneID` changes and triggers auto-scroll, the workspace MUST be effectively expanded (it is the selected workspace, so this is guaranteed by the effective collapse rule).
