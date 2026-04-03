# Collapsible Workspace Folders

## Why

With multiple workspaces each containing several panes (often grouped by branch), the sidebar becomes long and hard to scan. Users need a way to collapse workspaces they aren't actively using to reduce visual noise while keeping them accessible. The current flat-list design forces every workspace's full pane tree to be visible at all times.

## What Changes

- Workspace rows gain a collapse/expand toggle using the folder icon (`folder.fill` collapsed, `folder.open.fill` expanded)
- Collapsed workspaces hide their pane list; the selected (focused) workspace is always expanded
- Collapse state is persisted across app restarts via `WorkspaceSnapshot`
- Collapsed workspace rows show a summary status dot when child panes have attention or are thinking
- Sidebar keyboard navigation includes workspace rows as navigable targets, with left/right arrows to collapse/expand
- Context menu gains Collapse/Expand actions; command palette gains Collapse All / Expand All commands

## Capabilities

### New Capabilities

- **workspace-collapse**: Collapse/expand workspace folders in the sidebar, with persistence, keyboard navigation, and attention summary on collapsed rows
- **sidebar-keyboard-nav-workspaces**: Keyboard cursor can land on workspace rows (not just pane rows), with left/right arrow collapse/expand

### Modified Capabilities

- **sidebar-scrollbar**: `scrollTargetIDs` must exclude panes of collapsed workspaces to keep scroll targeting accurate

## Impact

- **Persistence**: `WorkspaceSnapshot` gains an optional `collapsedWorkspaceIDs` field (backward-compatible, defaults to empty set)
- **Model**: `AppModel` gains `collapsedWorkspaceIDs: Set<UUID>` and toggle/collapseAll/expandAll methods
- **Keyboard nav**: `SidebarKeyboardNav` returns a mixed enum of workspace/pane items instead of flat pane tuples
- **Cursor state**: `sidebarCursorPaneID` broadens to a `SidebarCursorTarget` enum (workspace or pane), threaded through `ContentView` and environment values
- **Commands**: Two new `AppCommand` cases for collapse all / expand all
- No database, route, dependency, or API changes
