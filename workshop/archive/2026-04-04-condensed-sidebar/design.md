# Design: Condensed Sidebar

## Approach

Add a `SidebarMode` enum to replace `sidebarVisible: Bool`, then build a new `CondensedSidebar` view that reuses existing model logic (workspace collapse, attention summaries, sidebar filters) but renders icon-only rows. `ContentView` switches between `WorkspaceSidebar` and `CondensedSidebar` based on mode.

## Key Decisions

### SidebarMode enum lives in HoottyCore

`SidebarMode` is a simple `String`-backed enum in HoottyCore alongside `AppModel`. It needs to be `Codable` for persistence and accessible from both HoottyCore (model) and Hootty (views).

File: `Sources/HoottyCore/SidebarMode.swift`

### CondensedSidebar is a new standalone view

Rather than adding mode branching inside `WorkspaceSidebar` (which is already ~640 lines), the condensed rail is a separate view file. It takes the same data inputs (workspaces, tokens, callbacks) but renders a fundamentally different layout. This keeps both views focused and avoids conditional complexity.

File: `Sources/Hootty/Views/CondensedSidebar.swift`

### Fixed width constant

`Layout.condensedSidebarWidth = 48` in `DesignTokens.swift`. This gives 8pt padding + 16pt icon + 16pt icon + 8pt padding. The icons use `TypeScale.smallSize` (12pt) within a `TreeLayout.columnWidth` (16pt) frame, centered in the 48pt column.

### ContentView sidebar switching

```
private var sidebarContent: some View {
    switch appModel.sidebarMode {
    case .full: sidebar        // existing WorkspaceSidebar
    case .condensed: condensedSidebar  // new CondensedSidebar
    case .hidden: EmptyView()  // not rendered (width = 0)
    }
}
```

The `workspacesContent` geometry calculation uses `Layout.condensedSidebarWidth` when mode is `.condensed` instead of `effectiveSidebarWidth`. The drag handle overlay only appears for `.full` mode.

### Backward-compatible persistence

`WorkspaceSnapshot` adds `sidebarMode: SidebarMode?`. The existing `sidebarVisible: Bool?` stays for reading old saves but is no longer written. Decode priority: `sidebarMode` > `sidebarVisible` fallback > default `.full`.

### Toggle cycles three states

`toggleSidebar()` rotates `.full → .condensed → .hidden → .full`. The menu label updates dynamically. The `focusSidebar` command forces `.full` mode since keyboard navigation needs the full sidebar.

### Row structure reuses StatusDotView icons

Condensed pane rows render the same icon/color logic as `StatusDotView` — they don't embed `StatusDotView` itself (which has a fixed 16pt frame for inline use), but use the same icon names and token colors. This keeps the visual language consistent.

### Keyboard navigation deferred

Keyboard nav (`onKeyPress` arrows/enter) in the condensed rail is out of scope for the initial implementation. The expand button and mouse interaction are sufficient. Full keyboard nav stays in the full sidebar.

| File | Role | Change |
|------|------|--------|
| `Sources/HoottyCore/SidebarMode.swift` | Model | New file: `SidebarMode` enum |
| `Sources/HoottyCore/AppModel.swift` | Model | Replace `sidebarVisible` with `sidebarMode`, update `toggleSidebar()` |
| `Sources/HoottyCore/DesignTokens.swift` | Tokens | Add `Layout.condensedSidebarWidth` |
| `Sources/HoottyCore/WorkspaceStore.swift` | Persistence | Add `sidebarMode` to snapshot, backward-compat decode |
| `Sources/Hootty/Views/CondensedSidebar.swift` | View | New file: condensed icon rail |
| `Sources/Hootty/Views/ContentView.swift` | View | Switch sidebar rendering by mode, adjust width calc |
| `Sources/Hootty/HoottyApp.swift` | App | Update command registration, menu label |
| `Tests/HoottyCoreTests/IntegrationTests.swift` | Tests | Update sidebar state assertions |
| `Tests/HoottyCoreTests/WorkspaceStoreTests.swift` | Tests | Snapshot decode/encode with new field |

## Dependencies

None. Uses existing SF Symbols, design tokens, and model infrastructure.
