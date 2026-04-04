# Tasks: Condensed Sidebar

## 1. SidebarMode Enum & Model Changes

- [x] 1.1 Create `Sources/HoottyCore/SidebarMode.swift` with `SidebarMode` enum (cases: `.full`, `.condensed`, `.hidden`), conforming to `String`, `Codable`, `Sendable`
- [x] 1.2 In `AppModel.swift`, replace `sidebarVisible: Bool = true` with `sidebarMode: SidebarMode = .full`
- [x] 1.3 Update `AppModel.toggleSidebar()` to cycle `.full → .condensed → .hidden → .full` instead of toggling a bool
- [x] 1.4 Add computed `AppModel.sidebarVisible: Bool` returning `sidebarMode != .hidden` for any remaining internal reads (or update all call sites directly)
- [x] 1.5 Update `AppModel.resetToDefaults()` to set `sidebarMode = .full` instead of `sidebarVisible = true`

## 2. Persistence

- [x] 2.1 Add `sidebarMode: SidebarMode?` to `WorkspaceSnapshot` in `WorkspaceStore.swift`
- [x] 2.2 Update `WorkspaceSnapshot.init` to accept `sidebarMode` parameter
- [x] 2.3 Update decode logic: if `sidebarMode` is present use it; else if `sidebarVisible` is present map `true → .full`, `false → .hidden`; else default `.full`
- [x] 2.4 Update encode logic: write `sidebarMode`, stop writing `sidebarVisible`
- [x] 2.5 Update `AppModel.init` snapshot restoration to read `sidebarMode` instead of `sidebarVisible`
- [x] 2.6 Update `AppModel.saveWorkspaces()` snapshot creation to write `sidebarMode` instead of `sidebarVisible`

## 3. Layout Constant

- [x] 3.1 Add `Layout.condensedSidebarWidth: CGFloat = 48` to `DesignTokens.swift`

## 4. ContentView Integration

- [x] 4.1 Update `ContentView.workspacesContent` sidebar width calculation to switch on `sidebarMode`: `.full` uses `effectiveSidebarWidth`, `.condensed` uses `Layout.condensedSidebarWidth`, `.hidden` uses `0`
- [x] 4.2 Update the sidebar rendering block: render `CondensedSidebar` when `.condensed`, `WorkspaceSidebar` when `.full`, nothing when `.hidden`
- [x] 4.3 Only show the drag handle overlay when `sidebarMode == .full`
- [x] 4.4 Update the `.animation` value from `appModel.sidebarVisible` to `appModel.sidebarMode`

## 5. CondensedSidebar View

- [x] 5.1 Create `Sources/Hootty/Views/CondensedSidebar.swift` with struct accepting: workspaces, selectedWorkspaceID binding, tokens, callbacks (onSelectPane, onRemoveWorkspace, onRemovePane, onToggleCollapse, onExpandSidebar, etc.), persistent panel props
- [x] 5.2 Build the expand button header row: `sidebar.left` icon in a `BarIconButton`, `Layout.barHeight` height, `tokens.tabBarBackground` background, bottom 1px border
- [x] 5.3 Build the pinned section: `pin.fill` header icon (tap toggles `persistentSidebarCollapsed`), pane icon rows when expanded, 1px divider below
- [x] 5.4 Build workspace folder icon rows: `folder`/`folder.fill`, tap toggles collapse, selected workspace gets `tokens.elementHover` background
- [x] 5.5 Build repo/branch section icon rows: `cube.fill` (HEAD) / `cube` (other), shown when workspace expanded and has branch sections
- [x] 5.6 Build pane status icon rows: icon and color matching `StatusDotView` logic (done/bell/thinking/claude/terminal), focused pane gets `tokens.elementSelected` background and `tokens.text` color
- [x] 5.7 Add animated rotation on thinking pane icons using `TimelineView(.animation)`
- [x] 5.8 Add attention summary indicator on collapsed workspace folder icons (using existing `WorkspaceAttentionSummary`)
- [x] 5.9 Add `.help()` tooltips on all rows: workspace name, branch label, pane displayName, "Expand sidebar"
- [x] 5.10 Add hover state (`tokens.elementHover` background) and pointing-hand cursor on all interactive rows
- [x] 5.11 Add context menus: workspace rows (Rename, Collapse/Expand, Close), pane rows (Rename, Move to Pinned, Close), pinned pane rows (Close, Move to Workspace), rail background ("New Workspace", "New Pinned Pane")
- [x] 5.12 Apply `activeSidebarFilters` to pane visibility (reuse `Pane.isVisibleInSidebar`)
- [x] 5.13 Set rail width to `Layout.condensedSidebarWidth`, background to `tokens.surfaceLow`
- [x] 5.14 Wrap rows in a `ScrollView` with `.scrollIndicators(.never)`

## 6. Command & Menu Updates

- [x] 6.1 Update `HoottyApp.registerCommands()`: `focusSidebar` handler must set `sidebarMode = .full` (not just `sidebarVisible = true`)
- [x] 6.2 Update View menu button label to reflect current mode: `.full` → "Condense Sidebar", `.condensed` → "Hide Sidebar", `.hidden` → "Show Sidebar"

## 7. Tests

- [x] 7.1 Update `IntegrationTests.sidebarStatePersistsAlongsideWorkspaces` to use `sidebarMode` instead of `sidebarVisible`/`toggleSidebar` bool assertions
- [x] 7.2 Update `WorkspaceStoreTests` snapshot decode/encode assertions for `sidebarMode`
- [x] 7.3 Add test: `toggleSidebar()` cycles `.full → .condensed → .hidden → .full`
- [x] 7.4 Add test: backward-compat decode of old snapshot with `sidebarVisible: true` → `sidebarMode == .full`
- [x] 7.5 Add test: backward-compat decode of old snapshot with `sidebarVisible: false` → `sidebarMode == .hidden`
- [x] 7.6 Run `swift test`, `make build`, `make format-check`, `make lint` — all pass
