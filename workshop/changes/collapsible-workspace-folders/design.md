# Design: Collapsible Workspace Folders

## Approach

Add collapse state to `AppModel`, persist it in `WorkspaceSnapshot`, and gate pane list rendering in `WorkspaceSidebar` on effective collapse state. Extend keyboard navigation to include workspace rows as cursor targets with left/right collapse/expand. The selected workspace is always visually expanded — collapse state is "latent" until the user switches away.

## Key Decisions

### Folder icon instead of chevron disclosure
Use `folder.fill` (collapsed) / `folder.open.fill` (expanded) as the workspace row icon. This avoids adding a separate disclosure triangle element and keeps the row layout identical — only the icon changes. The folder metaphor is already established by the current `folder.fill` icon.

### Selected workspace always expanded
Rather than removing the workspace from `collapsedWorkspaceIDs` on selection (which loses the user's intent), we compute an "effective" collapse state: `collapsedWorkspaceIDs.contains(id) && id != selectedWorkspaceID`. This means collapsing workspace A, switching to workspace B, then back to A shows A expanded — but switching away again collapses it. The user's collapse preference is sticky.

### Cursor target enum replaces bare UUID
`sidebarCursorPaneID: UUID?` becomes a `SidebarCursorTarget?` enum. This is the cleanest way to distinguish workspace rows from pane rows in the cursor state. The enum lives in `HoottyCore` (no UI dependency) so `SidebarKeyboardNav` can return it. The environment key changes from `UUID?` to `SidebarCursorTarget?`.

For backward compatibility with `SplitNodeView` (which only cares about pane cursors), add a computed `cursorPaneID: UUID?` that extracts the pane ID if the target is `.pane(...)`, returning nil for `.workspace(...)`.

### SidebarNavItem for navigation list
`SidebarKeyboardNav.allNavigableItems` returns `[SidebarNavItem]` where `SidebarNavItem` is an enum:
```
enum SidebarNavItem {
    case workspace(UUID)
    case pane(workspaceID: UUID, paneID: UUID)
}
```
This replaces the current `[(workspaceID: UUID, paneID: UUID)]` tuple array. The function accepts `collapsedWorkspaceIDs` and `selectedWorkspaceID` to compute effective collapse and skip panes accordingly.

### Attention summary on collapsed rows
`WorkspaceRow` receives an optional `summaryAttention: AttentionSummary?` (thinking/done/bell priority) computed by the parent. When non-nil, it renders a `StatusDotView` between the icon and the name. This keeps `WorkspaceRow` simple — it doesn't query panes directly.

### Collapse animation
Use `withAnimation(.easeInOut(duration: 0.15))` on the toggle. The pane list conditional `if !isEffectivelyCollapsed { workspacePaneList(...) }` gets a `.transition(.opacity.combined(with: .move(edge: .top)))` for smooth reveal/hide.

## Dependencies

No new external dependencies. All changes use existing SwiftUI and Foundation APIs.

### Files Modified

| File | Change |
|---|---|
| `Sources/HoottyCore/AppModel.swift` | Add `collapsedWorkspaceIDs`, toggle/collapseAll/expandAll methods, include in save |
| `Sources/HoottyCore/WorkspaceStore.swift` | Add `collapsedWorkspaceIDs` to `WorkspaceSnapshot` Codable |
| `Sources/HoottyCore/AppCommand.swift` | Add `collapseAllWorkspaces`, `expandAllWorkspaces` cases |
| `Sources/Hootty/Views/WorkspaceSidebar.swift` | Conditional pane list, effective collapse helper, left/right key handlers, scroll target filtering |
| `Sources/Hootty/Views/WorkspaceRow.swift` | Dynamic folder icon, cursor highlight, attention summary dot, context menu collapse/expand |
| `Sources/Hootty/Views/SidebarKeyboardNav.swift` | `SidebarNavItem` enum, `SidebarCursorTarget` enum, updated navigation with workspace rows |
| `Sources/Hootty/Views/SidebarPaneRow.swift` | Accept `SidebarCursorTarget?` for cursor check (minor) |
| `Sources/Hootty/Views/ContentView.swift` | Thread `SidebarCursorTarget?` instead of `UUID?` |
| `Sources/Hootty/HoottyApp.swift` | Register collapse all / expand all commands |
| `Tests/HoottyCoreTests/` | Integration tests for collapse persistence, unit tests for nav logic |
