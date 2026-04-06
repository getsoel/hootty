# Pin Workspace — Tasks

## 1. Remove Docked Panel Model & Persistence

- [x] 1.1 Delete `Sources/HoottyCore/PanelPosition.swift`
- [x] 1.2 Delete `Sources/HoottyCore/FocusDomain.swift`
- [x] 1.3 Remove all persistent panel properties from `AppModel.swift`: `persistentNode`, `persistentPanelVisible`, `persistentPanelWidth`, `persistentPanelHeight`, `persistentPanelPosition`, `persistentFocusedPaneID`, `persistentSidebarCollapsed`, `focusDomain`
- [x] 1.4 Remove `persistentFocusedPane` computed property and `persistentPanes` from `AppModel`
- [x] 1.5 Remove all persistent panel methods from `AppModel`: `togglePersistentPanel`, `closePersistentPanel`, `removePersistentPane`, `splitPersistentPane`, `addPersistentPane`, `cyclePersistentFocus`, `movePaneToPersistentPanel`, `movePaneToWorkspace`, `setPanelPosition`
- [x] 1.6 Remove persistent panel static constants from `AppModel` (`defaultPanelWidth`, `defaultPanelHeight`, `defaultPanelPosition`, min/max sizes, `persistentWorkspaceID`)
- [x] 1.7 Remove `focusPaneInDirection` cross-domain logic (simplify to workspace-only)
- [x] 1.8 Remove persistent panel fields from `WorkspaceSnapshot` in `WorkspaceStore.swift` (both encoding and decoding)
- [x] 1.9 Remove persistent panel snapshot restoration in `AppModel.init`

## 2. Add Pin Workspace Model & Persistence

- [x] 2.1 Add `pinnedWorkspaceID: UUID?` property to `AppModel`
- [x] 2.2 Add `togglePinWorkspace(id:)` method to `AppModel`
- [x] 2.3 Clear `pinnedWorkspaceID` in `removeWorkspace(id:)` and `removeWorkspace(at:)` if the pinned workspace is deleted
- [x] 2.4 Add optional `pinnedWorkspaceID` field to `WorkspaceSnapshot`, encode only when non-nil
- [x] 2.5 Restore `pinnedWorkspaceID` from snapshot in `AppModel.init`

## 3. Remove Docked Panel Commands

- [x] 3.1 Remove `toggleDockedPanel`, `focusDockedPanel`, `movePaneToDockedPanel`, `movePaneToWorkspace`, `movePanelLeft`, `movePanelRight`, `movePanelTop`, `movePanelBottom` cases from `AppCommand`
- [x] 3.2 Remove corresponding command handlers in `HoottyApp.registerCommands()`
- [x] 3.3 Simplify `focusNextPane`/`focusPreviousPane` handlers to remove persistent domain branching
- [x] 3.4 Simplify `focusPaneUp/Down/Left/Right` handlers to remove cross-domain logic
- [x] 3.5 Remove docked panel menu items from `.commands` block if any exist

## 4. Add Pin Workspace Commands

- [x] 4.1 Add `pinWorkspace` and `focusPinnedWorkspace` cases to `AppCommand` with titles and shortcut hints
- [x] 4.2 Register `pinWorkspace` handler: call `appModel.togglePinWorkspace(id:)` with selected workspace
- [x] 4.3 Register `focusPinnedWorkspace` handler: set `selectedWorkspaceID = pinnedWorkspaceID`
- [x] 4.4 Add `focusPinnedWorkspace` to Window menu with Cmd+\ shortcut

## 5. Remove Docked Panel UI

- [x] 5.1 Remove panel layout computation from `ContentView.swift` (`computePanelLayout`, `PanelLayout` struct, `effectivePanelSize`)
- [x] 5.2 Remove panel rendering, divider, and drag handle from `ContentView.workspacesContent`
- [x] 5.3 Remove persistent panel view builder from `ContentView`
- [x] 5.4 Remove all persistent panel parameters and callbacks from `ContentView` → sidebar calls (`persistentNode`, `persistentFocusedPaneID`, `persistentSidebarCollapsed`, `onSelectPersistentPane`, `onRemovePersistentPane`, `onNewPersistentPane`, `onCloseAllPersistentPanes`, `onMovePaneToWorkspace`, `onMovePaneToPinned`, `onToggleDockedPanel`, `dockedPanelVisible`)
- [x] 5.5 Remove "Docked" section from `WorkspaceSidebar.swift` (pseudo-workspace row, pane rows, collapse toggle, drop target, context menu)
- [x] 5.6 Remove persistent panel parameters from `WorkspaceSidebar` init
- [x] 5.7 Remove persistent panel section from `CondensedSidebar.swift` (`pinnedSection`, related parameters)
- [x] 5.8 Remove dock position menu from `PaneGroupTabBar.swift`
- [x] 5.9 Remove `DockPositionKey`, `SetDockPositionKey`, and related environment extensions from `TerminalPaneView.swift`
- [x] 5.10 Remove persistent pseudo-workspace handling from `SidebarNavigation.swift` (`allNavigableItems`, `moveCursor`, `workspaceForPane`)

## 6. Add Pin Workspace Sidebar UI

- [x] 6.1 Add sidebar display ordering: pinned workspace sorted first in workspace list
- [x] 6.2 Add pin icon indicator on pinned workspace row (SF Symbol `pin.fill`, muted color)
- [x] 6.3 Add "Pin Workspace" / "Unpin Workspace" context menu item on workspace rows

## 7. Update Tests

- [x] 7.1 Remove persistent panel integration tests from `IntegrationTests.swift` (panel round-trip, position round-trip, default state, pane movement)
- [x] 7.2 Add test: `togglePinWorkspace` pins and unpins
- [x] 7.3 Add test: deleting pinned workspace clears `pinnedWorkspaceID`
- [x] 7.4 Add test: `pinnedWorkspaceID` persistence round-trip via `WorkspaceSnapshot`
- [x] 7.5 Run `swift test`, `make build`, `make format-check`, `make lint` to verify everything passes
