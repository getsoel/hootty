# Design: Persistent Terminal Panel

## Approach

Add a persistent terminal panel as a right-side region in ContentView, backed by its own `SplitNode` tree on `AppModel`. The panel reuses existing infrastructure (`SplitNodeView`, `PaneContentView`, `TerminalSurfaceView`) — no new rendering or terminal abstractions. The sidebar gains a pseudo-workspace entry at the top that renders the panel's panes using existing `SidebarPaneRow`. A `FocusDomain` enum tracks whether application focus is in the workspace or persistent panel, enabling split focus behavior across the boundary.

## Key Decisions

### Separate SplitNode, not a special Workspace

The persistent panel owns a `SplitNode?` directly on `AppModel`, not a `Workspace` with an `isPersistent` flag. Rationale:
- Workspace has semantics that don't apply (name, repoPath, headBranches, workspace-level focus cycling).
- Adding a boolean flag to Workspace introduces conditional logic everywhere workspaces are iterated (sidebar, save/load, collapse, keyboard nav, drag-drop).
- A separate property is explicit: code that operates on workspaces doesn't accidentally include the persistent panel.
- The sidebar renders the panel as a pseudo-workspace row with hardcoded behavior, not a parameterized WorkspaceRow.

### Sentinel UUID for sidebar navigation

The persistent pseudo-workspace needs a stable ID for `SidebarNavItem.workspace(UUID)`. Use a hardcoded sentinel UUID (e.g., `UUID(uuidString: "00000000-0000-0000-0000-000000000001")!`) as a constant on `AppModel`. This avoids changing the `SidebarNavItem` enum to add a `.persistentWorkspace` case, keeping the keyboard nav code generic. The sentinel is checked at dispatch sites (confirm cursor, collapse toggle) to route to persistent-panel-specific behavior.

### FocusDomain enum for split focus

Rather than a boolean `isPersistentFocused`, use `FocusDomain` enum (`.workspace`, `.persistent`). This:
- Makes switch statements exhaustive (compiler catches missing cases).
- Is extensible if future panel types are added.
- Reads clearly at call sites: `if focusDomain == .persistent`.

### Directional focus via combined pane rects

`SplitNode.paneRects()` returns normalized [0,1] rects. For cross-domain directional focus, compute two rect sets:
1. Workspace rects mapped to `CGRect(x: 0, y: 0, width: detailFraction, height: 1)`.
2. Persistent rects mapped to `CGRect(x: 1 - panelFraction, y: 0, width: panelFraction, height: 1)`.

Merge into a single `[UUID: CGRect]` dict and run the existing nearest-in-direction algorithm. This reuses `Workspace.focusPaneInDirection` geometry logic without modifying it — just changing the input rect set.

### Pane movement preserves object identity

Moving a pane between workspace and persistent panel removes it from one `SplitNode` tree and inserts it into another. The `Pane` instance (reference type, `@Observable`) is the same object — no copy, no re-creation. The `GhosttyApp` surface view cache is keyed by `Pane.id` (UUID), so the cached `TerminalSurfaceView` remains valid. The ghostty surface continues running its PTY session uninterrupted.

### Panel sidebar is a custom view, not a parameterized WorkspaceRow

The persistent pseudo-workspace row differs enough from WorkspaceRow (no rename, no delete, no drag-reorder, different icon, different click behavior) that parameterizing WorkspaceRow would add more conditional complexity than building a small dedicated view. The pane rows below it reuse `SidebarPaneRow` unchanged.

### WorkspaceSnapshot evolution

New optional fields on `WorkspaceSnapshot` for backward compatibility. Existing saves without the panel decode to `nil`/`false`/default. The snapshot is already JSON with optional fields (`sidebarVisible`, `collapsedWorkspaceIDs`), so this follows the established pattern.

## Dependencies

No new external dependencies. All implementation uses existing:
- `SplitNode` / `SplitNodeView` for tree management and rendering
- `PaneContentView` / `TerminalSurfaceView` for terminal display
- `SidebarPaneRow` for sidebar pane rendering
- `GhosttyApp` surface caching and lifecycle
- `WorkspaceStore` JSON serialization
- `AppCommand` / `CommandRegistry` for command integration
