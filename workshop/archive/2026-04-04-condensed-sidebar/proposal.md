# Condensed Sidebar

## Why

The sidebar currently has only two states: fully visible (200–400pt) or completely hidden. When working with a single workspace and wanting maximum terminal space, hiding the sidebar loses all visual context — workspace status, pane attention states, and quick switching. A narrow icon-only rail provides a middle ground: minimal width (~48pt) while preserving at-a-glance workspace and pane status through icons alone.

## What Changes

- Replace the boolean `sidebarVisible` state with a three-value `SidebarMode` enum (`.full`, `.condensed`, `.hidden`).
- Add a new `CondensedSidebar` view — a narrow icon rail showing workspace folder icons, repo section icons, and pane status icons without text.
- Update `ContentView` to render either the full sidebar or the condensed rail based on mode, with no drag handle in condensed mode.
- Update the `toggleSidebar` command to cycle through all three modes.
- Add backward-compatible persistence for the new mode enum.

## Capabilities

### New Capabilities

- **condensed-sidebar-rail**: A narrow icon-only sidebar showing workspace, repo, and pane icons with status indicators. Expand button at top, collapsible workspaces, tooltips on hover, context menus on right-click. No drag-and-drop or "+" button — those actions are accessible via context menu or by expanding to full mode.

### Modified Capabilities

- **sidebar-mode-state**: Replaces `sidebarVisible: Bool` with `SidebarMode` enum on `AppModel` and `WorkspaceSnapshot`. Toggle command cycles full → condensed → hidden → full. Backward-compatible with existing persisted `sidebarVisible` field.

## Impact

- **Persistence**: `WorkspaceSnapshot` gains an optional `sidebarMode` field. Existing saves without it decode via the old `sidebarVisible` boolean (true → `.full`, false → `.hidden`). No migration needed.
- **Dependencies**: None. Uses existing SF Symbols and design tokens.
- **Keyboard shortcuts**: `⇧⌘S` behavior changes from two-state toggle to three-state cycle.
