# Tasks: Persistent Terminal Panel

## 1. Model Foundation

- [x] 1.1 Add `FocusDomain` enum (`.workspace`, `.persistent`) to `Sources/HoottyCore/`
- [x] 1.2 Add persistent panel properties to `AppModel`: `persistentNode: SplitNode?`, `persistentPanelVisible: Bool`, `persistentPanelWidth: CGFloat`, `persistentFocusedPaneID: UUID?`, `focusDomain: FocusDomain`
- [x] 1.3 Add static constants `persistentPanelMinWidth` (200), `persistentPanelMaxWidth` (600), and sentinel `persistentWorkspaceID` UUID on `AppModel`
- [x] 1.4 Add computed `persistentFocusedPane: Pane?` resolving ID against `persistentNode`
- [x] 1.5 Add panel lifecycle methods: `togglePersistentPanel()` (creates default pane if nil), `closePersistentPanel()` (nils node, hides)
- [x] 1.6 Modify `findPane(id:)` and `withPane(id:)` to also search `persistentNode`
- [x] 1.7 Modify `resetWorkspaces()` to clear persistent panel state
- [x] 1.8 Write unit tests for model properties and lifecycle (panel creation, last-pane removal nils node, findPane searches persistent)

## 2. Persistence

- [x] 2.1 Add optional `persistentNode: SplitNode?`, `persistentPanelVisible: Bool?`, `persistentPanelWidth: CGFloat?` fields to `WorkspaceSnapshot`
- [x] 2.2 Modify `AppModel.saveWorkspaces()` to include persistent panel state in snapshot
- [x] 2.3 Modify `AppModel.init` to restore persistent panel state from snapshot on load
- [x] 2.4 Write integration test: save with persistent panel, reload, verify state round-trips
- [x] 2.5 Write integration test: load old snapshot without persistent fields, verify defaults (nil/false)

## 3. Layout

- [ ] 3.1 Add persistent panel rendering in `ContentView.workspacesContent`: panel view + 1px divider + 16px drag handle to the right of detail area
- [ ] 3.2 Adjust detail area width calculation to subtract `persistentPanelWidth + 1` when visible
- [ ] 3.3 Implement drag-to-resize with `@GestureState` (mirror left sidebar pattern), clamp to min/max, commit on end, call `debouncedSave()`
- [ ] 3.4 Wire `SplitNodeView` for the persistent panel with correct callbacks (split/close/focus operating on `persistentNode`)
- [ ] 3.5 Add show/hide animation (`.easeInOut(duration: 0.2)`) driven by `persistentPanelVisible`
- [ ] 3.6 Handle surface cleanup: call `GhosttyApp.shared.removeCachedSurfaceView(for:)` when closing persistent panes

## 4. Commands

- [ ] 4.1 Add `AppCommand` cases: `togglePersistentPanel` (title: "Toggle Persistent Panel", hint: "⌘⌥P"), `focusPersistentPanel` (title: "Focus Persistent Panel", hint: "⌘\\"), `movePaneToPersistentPanel` (title: "Move Pane to Pinned"), `movePaneToWorkspace` (title: "Move Pane to Workspace")
- [ ] 4.2 Register command handlers in `HoottyApp.registerCommands()`
- [ ] 4.3 Add menu bar items under View menu: "Toggle Persistent Panel" with `.keyboardShortcut("p", modifiers: [.command, .option])`, "Focus Persistent Panel" with `.keyboardShortcut("\\", modifiers: [.command])`
- [ ] 4.4 Wire split commands to detect `focusDomain` and dispatch to persistent node or workspace node accordingly
- [ ] 4.5 Wire ghostty action callbacks (`GhosttyApp.handleAction`) to route split/close actions from persistent surfaces to the persistent node

## 5. Focus System

- [ ] 5.1 Implement `focusDomain` tracking: set to `.persistent` when persistent pane focused, `.workspace` when workspace pane focused
- [ ] 5.2 Modify `focusNextPane` / `focusPreviousPane` to cycle within current domain only
- [ ] 5.3 Implement `focusPersistentPanel` command handler: toggle between domains, restoring last-focused pane in each
- [ ] 5.4 Implement cross-domain directional focus: compute combined pane rects (workspace rects in left region, persistent rects in right region), run nearest-in-direction algorithm
- [ ] 5.5 Update focus visual indicators: active domain shows focus border, inactive domain dims
- [ ] 5.6 Handle focus on last-pane-close: switch domain to `.workspace` when persistent panel empties
- [ ] 5.7 Write unit tests for sequential cycling isolation and domain switching

## 6. Sidebar: Pseudo-Workspace Row

- [ ] 6.1 Create `PersistentPanelRow` view (pin icon, "Pinned" label, attention summary dot when collapsed)
- [ ] 6.2 Render `PersistentPanelRow` at the top of `WorkspaceSidebar` workspace list, above regular workspaces, with a divider below
- [ ] 6.3 Only show the row when `persistentNode != nil`
- [ ] 6.4 Wire click to toggle sidebar collapse of the persistent section
- [ ] 6.5 Wire pane rows: render `SidebarPaneRow` for persistent panes, clicking focuses pane and sets `persistentPanelVisible = true`
- [ ] 6.6 Add context menu on pseudo-workspace row: "New Pane", "Close All"
- [ ] 6.7 Add context menu on persistent pane rows: "Close Pane", "Move to Workspace" (submenu with workspace names)

## 7. Sidebar: Keyboard Nav & Filters

- [ ] 7.1 Modify `SidebarKeyboardNav.allNavigableItems` to prepend persistent pseudo-workspace + its panes (using sentinel UUID)
- [ ] 7.2 Handle Enter on persistent workspace row: toggle sidebar collapse (not select workspace)
- [ ] 7.3 Handle left/right arrow on persistent workspace row: collapse/expand its pane list
- [ ] 7.4 Handle Enter on persistent pane row: focus pane, set `focusDomain = .persistent`, show panel if hidden
- [ ] 7.5 Modify sidebar badge filter counts to include persistent panel panes in aggregation
- [ ] 7.6 Apply filter visibility to persistent pane rows (same matching logic, pinned focused pane always visible)

## 8. Pane Movement

- [ ] 8.1 Implement `AppModel.movePaneToPersistentPanel(paneID:)`: remove from workspace split tree, add to persistent node as vertical split, preserve Pane object identity
- [ ] 8.2 Implement `AppModel.movePaneToWorkspace(paneID:, workspaceID:)`: remove from persistent node, add to workspace split tree, preserve Pane identity
- [ ] 8.3 Handle edge cases: moving last workspace pane creates default replacement, moving last persistent pane nils node and hides panel
- [ ] 8.4 Wire "Move to Pinned" context menu on workspace pane rows
- [ ] 8.5 Wire "Move to Workspace" context menu on persistent pane rows (submenu of workspaces)
- [ ] 8.6 Optionally implement drag-and-drop between sidebar sections (persistent ↔ workspace)
- [ ] 8.7 Write integration tests: move pane to persistent panel, verify surface cache preserved, move back, verify round-trip
- [ ] 8.8 Write integration tests: move last pane from persistent panel, verify cleanup; move last pane from workspace, verify default created

## 9. Verify & Polish

- [ ] 9.1 `make build` succeeds
- [ ] 9.2 `swift test` passes
- [ ] 9.3 `make format-check` passes
- [ ] 9.4 `make lint` passes
- [ ] 9.5 Manual test: toggle panel, split panes, resize divider, switch workspaces (panel persists)
- [ ] 9.6 Manual test: directional focus crosses boundary, sequential cycling stays within domain
- [ ] 9.7 Manual test: move pane to/from persistent panel via command and context menu, terminal session survives
- [ ] 9.8 Manual test: quit and relaunch, persistent panel state restored
