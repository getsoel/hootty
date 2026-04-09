## 1. AppCommand cleanup

- [x] 1.1 Delete `refreshBranches` case from `AppCommand` in `Sources/HoottyCore/AppCommand.swift` (enum case + `title` switch branch)
- [x] 1.2 Remove `shortcutHint` entries for `nextWorkspace` (`"⌃⇥"`) and `previousWorkspace` (`"⌃⇧⇥"`) in `Sources/HoottyCore/AppCommand.swift`
- [x] 1.3 Remove the `commandRegistry.register(.refreshBranches) { … }` no-op handler from `HoottyApp.registerCommands()` in `Sources/Hootty/HoottyApp.swift`
- [x] 1.4 Grep the repo for any other references to `refreshBranches` (tests, docs, CLAUDE.md) and remove them

## 2. App menu (Hootty ▸ settings-type modals)

- [x] 2.1 Extend `CommandGroup(replacing: .appSettings)` in `HoottyApp.swift` to include an `Attention Sounds…` button after `Edit Configuration…`, separated by a `Divider()`
- [x] 2.2 Wire the `Attention Sounds…` button to `commandRegistry.execute(.attentionSounds)`; no keyboard shortcut

## 3. View menu merge

- [x] 3.1 Delete the `CommandMenu("View") { … }` block in `HoottyApp.swift`
- [x] 3.2 Add `CommandGroup(after: .sidebar) { … }` in its place containing (in order, with dividers):
      Command Palette (`⇧⌘P`), divider,
      Toggle Sidebar (`⇧⌘S` — label via `sidebarToggleLabel`),
      Focus Sidebar (`⌘0`), divider,
      Collapse All Workspaces,
      Expand All Workspaces,
      Clear Sidebar Filters, divider,
      Focus Pinned Workspace (`⌘\`)
- [x] 3.3 Verify in a running build that exactly one `View` menu appears in the menu bar and it contains all the items above (deferred to task 8.3 click-through)

## 4. Theme menu removal

- [x] 4.1 Delete the `CommandMenu("Theme") { … }` block from `HoottyApp.swift`
- [x] 4.2 Confirm `commandRegistry.register(.changeTheme)` remains registered so the command palette still exposes it

## 5. Workspace menu (rename from Shell, consolidate actions)

- [x] 5.1 Rename `CommandMenu("Shell")` to `CommandMenu("Workspace")` in `HoottyApp.swift`
- [x] 5.2 Reorganize the contents to match the design (groups separated by dividers):
      Group 1: New Workspace (`⌘T`), Close Workspace (no shortcut)
      Group 2: Split Right (`⌘D`), Split Down (`⇧⌘D`), Split Left (`⌥⌘D`), Split Up (`⌥⇧⌘D`), Equalize Splits (`⌃⇧=`)
      Group 3: Next Workspace (no shortcut), Previous Workspace (no shortcut)
      Group 4: Focus Pane Up/Down/Left/Right (`⌥⌘↑↓←→`)
      Group 5: Note Pane (`⌃⇧F`), Flag Pane (`⌃⇧G`)
      Group 6: Pin/Unpin Workspace (no shortcut), Refresh Terminal (no shortcut)
- [x] 5.3 Wire each new menu button to `commandRegistry.execute(.<appCommand>)` (no new `AppCommand` cases needed — all are already registered)
- [x] 5.4 Apply `.disabled(appModel.selectedWorkspace == nil)` to the `Close Workspace` button
- [x] 5.5 Apply `.disabled(appModel.workspaces.count < 2)` to `Next Workspace` and `Previous Workspace` — disabled when fewer than two workspaces exist in the active profile
- [x] 5.6 Apply `.disabled(appModel.selectedWorkspaceID == nil)` to `Pin/Unpin Workspace`

## 6. Test and doc updates

- [x] 6.1 Run `swift test` (ignore signal 10 exit per CLAUDE.local.md) and fix any `AppCommand`-related assertions that break due to the `refreshBranches` removal — all 278 tests pass, no `AppCommand`-count assertions exist
- [x] 6.2 Update `CLAUDE.md` Architecture section if any referenced command identifier changed (spot-check that `refreshBranches` is not named anywhere in docs) — CLAUDE.md has no references to changed identifiers; `docs/` directory is untracked in this repo

## 7. Build + lint verification

- [ ] 7.1 `make build` succeeds
- [ ] 7.2 `swift test` passes (all Swift Testing tests green)
- [ ] 7.3 `make format-check` passes
- [ ] 7.4 `make lint` passes

## 8. Manual verification

- [ ] 8.1 Launch the app via `make run` and confirm the menu bar shows exactly: `Hootty`, `File`, `Edit`, `View`, `Workspace`, `Profile`, `Window`, `Help`
- [ ] 8.2 Walk the `Hootty` menu: confirm `Edit Configuration…` (`⌘,`) and `Attention Sounds…` are both present, separated by a divider, and both open the expected modals
- [ ] 8.3 Walk the `View` menu: confirm Command Palette, Toggle Sidebar, Focus Sidebar, Collapse/Expand All, Clear Sidebar Filters, Focus Pinned Workspace are all present and dispatch correctly
- [ ] 8.4 Walk the `Workspace` menu: confirm every item from task 5.2 is present, in order, with correct keyboard shortcut labels (or no label for shortcut-less items)
- [ ] 8.5 Trigger disabled states: delete all workspaces → confirm `Close Workspace` and `Pin/Unpin Workspace` are disabled; create exactly one workspace → confirm `Next Workspace` and `Previous Workspace` are disabled
- [ ] 8.6 Open the command palette: confirm `Change Theme...` is still listed, `Refresh Branches` is gone, and `Next Workspace` / `Previous Workspace` display no shortcut label
- [ ] 8.7 Confirm no menu titled `Shell` or `Theme` exists anywhere in the menu bar
