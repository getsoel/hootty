# Persistent Terminal Panel

## Why

All terminal panes currently live inside workspace split trees. Switching workspaces replaces the entire terminal area, so there's no way to keep a terminal visible across workspace changes. Common workflows — watching a log tail, keeping a build running, monitoring a dev server — require a terminal that persists regardless of which workspace is active.

## What Changes

- Add a right-side panel to `ContentView` that renders its own `SplitNode` tree, independent of any workspace
- Add persistent panel state to `AppModel` (node, visibility, width)
- Render the persistent panel as a pseudo-workspace in the left sidebar (pinned to the top, pin icon instead of folder)
- Add commands and keyboard shortcuts: toggle panel visibility, focus panel, split within panel, move pane to/from panel
- Extend directional focus to cross the workspace/panel boundary
- Persist the panel's pane tree alongside workspaces in `WorkspaceStore`

## Capabilities

### New Capabilities

- **persistent-panel-layout**: Right-side panel in `ContentView` with resizable divider, rendering a separate `SplitNode` tree. Supports vertical splits within the panel.
- **persistent-panel-model**: `AppModel` properties for the panel's split node, visibility, and width. Serialized via `WorkspaceStore`.
- **persistent-panel-sidebar**: Pseudo-workspace entry at the top of the sidebar with pin icon. Shows panel panes using existing `SidebarPaneRow`. Not reorderable or deletable.
- **persistent-panel-commands**: Commands for toggling panel, focusing panel, splitting within panel, and moving panes between workspaces and the panel.
- **persistent-panel-focus**: Directional focus (Cmd+arrow) crosses the workspace/panel boundary. Sequential cycling (Cmd+]/[) stays within the current domain. Dedicated shortcut to jump focus between domains.
- **persistent-panel-pane-movement**: Move panes between workspaces and the persistent panel via command or drag-and-drop.

### Modified Capabilities

- **workspace-collapse**: Sidebar rendering must account for the pinned pseudo-workspace at the top (it does not participate in collapse/expand).
- **sidebar-badge-filters**: Badge counts and filter matching must include persistent panel panes.
- **sidebar-keyboard-nav-workspaces**: Navigable items list must include the persistent pseudo-workspace and its panes at the top.

## Impact

- **WorkspaceStore / persistence**: Snapshot format gains a `persistentNode` field (optional, backward-compatible).
- **ContentView layout**: `workspacesContent` ZStack gains a right panel + divider alongside existing sidebar + detail.
- **Focus system**: `focusPaneInDirection` must compute rects across both the workspace detail and the persistent panel.
- **Sidebar**: Workspace list gains a fixed pseudo-entry at the top.
- **No new dependencies** — uses existing `SplitNode`, `SplitNodeView`, `PaneContentView`, and ghostty surface infrastructure.
