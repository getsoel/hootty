# Tasks: Collapsible Workspace Folders

## 1. Model & Persistence

- [ ] 1.1 Add `collapsedWorkspaceIDs: Set<UUID>` property to `AppModel` in `Sources/HoottyCore/AppModel.swift`
- [ ] 1.2 Add `toggleWorkspaceCollapse(_:)`, `collapseAllWorkspaces()`, `expandAllWorkspaces()` methods to `AppModel`
- [ ] 1.3 Clean removed workspace IDs from `collapsedWorkspaceIDs` in `removeWorkspace(id:)` and `removeWorkspace(at:)`
- [ ] 1.4 Add optional `collapsedWorkspaceIDs: Set<UUID>?` to `WorkspaceSnapshot` in `Sources/HoottyCore/WorkspaceStore.swift` with Codable support (default to empty set on decode)
- [ ] 1.5 Include `collapsedWorkspaceIDs` in `AppModel.saveWorkspaces()` snapshot and restore in `init`
- [ ] 1.6 Add `isWorkspaceEffectivelyCollapsed(_:)` helper to `AppModel`: returns true when ID is in collapsed set AND not `selectedWorkspaceID`
- [ ] 1.7 Add integration test: collapse state persists through save/load round-trip via `WorkspaceStore` with temp file

## 2. Cursor Target & Navigation Types

- [ ] 2.1 Add `SidebarCursorTarget` enum (`.workspace(UUID)`, `.pane(UUID)`) to `Sources/Hootty/Views/SidebarKeyboardNav.swift` with computed `cursorPaneID: UUID?` helper
- [ ] 2.2 Add `SidebarNavItem` enum (`.workspace(UUID)`, `.pane(workspaceID: UUID, paneID: UUID)`) to `SidebarKeyboardNav`
- [ ] 2.3 Update `SidebarKeyboardNav.allNavigableItems` to return `[SidebarNavItem]`, accept `collapsedWorkspaceIDs: Set<UUID>` and `selectedWorkspaceID: UUID?`, insert workspace rows, skip panes of effectively collapsed workspaces
- [ ] 2.4 Update `moveCursor` to work with `SidebarCursorTarget` input/output and `SidebarNavItem` list
- [ ] 2.5 Update `confirmCursor` to return `SidebarNavItem?` and handle both workspace and pane targets
- [ ] 2.6 Add unit tests for `allNavigableItems` with collapsed workspaces, `moveCursor` across workspace/pane boundaries

## 3. Sidebar Collapse Rendering

- [ ] 3.1 Thread `collapsedWorkspaceIDs` (or an `isEffectivelyCollapsed` closure) into `WorkspaceSidebar` from `ContentView`
- [ ] 3.2 Gate `workspacePaneList(workspace)` on effective collapse state in `WorkspaceSidebar.workspaceList`
- [ ] 3.3 Add collapse/expand animation (`.easeInOut(duration: 0.15)` with opacity+move transition)
- [ ] 3.4 Update `scrollTargetIDs` to exclude pane IDs of effectively collapsed workspaces

## 4. Workspace Row Updates

- [ ] 4.1 Add `isCollapsed: Bool` and `summaryAttention` params to `WorkspaceRow`
- [ ] 4.2 Change folder icon: `folder.fill` when collapsed, `folder.open.fill` when expanded
- [ ] 4.3 Add `StatusDotView` between icon and name when collapsed and child panes have attention/thinking
- [ ] 4.4 Add `isCursorTarget: Bool` param and render cursor highlight overlay (matching `SidebarPaneRow` style)
- [ ] 4.5 Add "Collapse" / "Expand" to context menu (omit for selected workspace)
- [ ] 4.6 Pass attention summary from `WorkspaceSidebar` — compute highest-priority status (thinking > done > bell) from workspace's panes

## 5. Keyboard Navigation Integration

- [ ] 5.1 Replace `sidebarCursorPaneID: UUID?` with `sidebarCursorTarget: SidebarCursorTarget?` in `WorkspaceSidebar` `@State` and `ContentView` `@Binding`
- [ ] 5.2 Update environment key from `sidebarCursorPaneID` to propagate `SidebarCursorTarget?` (add computed `cursorPaneID` for `SplitNodeView` compatibility)
- [ ] 5.3 Add `.onKeyPress(.leftArrow)` handler in `WorkspaceSidebar`: if cursor is on workspace row, collapse it; if on pane row, move cursor to parent workspace row
- [ ] 5.4 Add `.onKeyPress(.rightArrow)` handler in `WorkspaceSidebar`: if cursor is on workspace row, expand it
- [ ] 5.5 Update `confirmCursor()` call to handle workspace targets (select workspace) vs pane targets (select and focus pane)
- [ ] 5.6 Update `moveCursor` calls to pass `collapsedWorkspaceIDs` and `selectedWorkspaceID`

## 6. Commands

- [ ] 6.1 Add `collapseAllWorkspaces` and `expandAllWorkspaces` cases to `AppCommand` in `Sources/HoottyCore/AppCommand.swift` with titles
- [ ] 6.2 Register handlers in `HoottyApp.registerCommands()` calling `appModel.collapseAllWorkspaces()` / `appModel.expandAllWorkspaces()`

## 7. Verification

- [ ] 7.1 `make build` succeeds
- [ ] 7.2 `swift test` passes
- [ ] 7.3 `make format-check` passes
- [ ] 7.4 `make lint` passes
- [ ] 7.5 Manual test: collapse/expand workspace via click, context menu, keyboard, and command palette
- [ ] 7.6 Manual test: selected workspace always shows panes; switching away re-collapses
- [ ] 7.7 Manual test: attention dot appears on collapsed workspace row when child pane has attention
