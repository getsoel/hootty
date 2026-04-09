## ADDED Requirements

### Requirement: Single View Menu

The macOS menu bar SHALL contain exactly one menu titled `View`. Hootty-specific items SHALL be added to SwiftUI's auto-generated `View` menu via `CommandGroup(after:)` rather than via `CommandMenu("View")`, to prevent duplicate top-level menus with the same title.

#### Scenario: Menu bar has one View menu at launch

- **WHEN** the app launches with any configuration
- **THEN** exactly one menu titled `View` appears in the menu bar and it contains both the Hootty-specific items and the system-provided items (toolbar/sidebar controls)

#### Scenario: No stray CommandMenu View

- **WHEN** the source `HoottyApp.swift` is inspected
- **THEN** there is no `CommandMenu("View")` declaration; Hootty's View items are added via `CommandGroup(after: .sidebar)` (or equivalent placement anchor)

### Requirement: Top-Level Menu Order

The macOS menu bar SHALL present Hootty-authored top-level menus in the following order after the system-provided `Hootty`, `File`, `Edit`, and `View` menus, and before the system-provided `Window` and `Help` menus:

1. `Workspace`
2. `Profile`

#### Scenario: Menu order at launch

- **WHEN** the app launches
- **THEN** the menu bar shows, in order: `Hootty`, `File`, `Edit`, `View`, `Workspace`, `Profile`, `Window`, `Help`

### Requirement: No Theme Menu

The macOS menu bar SHALL NOT contain a top-level `Theme` menu. The `changeTheme` AppCommand SHALL remain registered in `CommandRegistry` so the command is reachable from the command palette, but SHALL NOT be exposed via a menu bar entry.

#### Scenario: No Theme menu at launch

- **WHEN** the app launches
- **THEN** no menu bar entry titled `Theme` is present

#### Scenario: Change Theme still in palette

- **WHEN** the user opens the command palette
- **THEN** the entry `Change Theme...` is listed and invoking it opens the theme picker modal

### Requirement: View Menu Contents

The `View` menu SHALL contain, in order, with separators between groups:

Group 1 (palette + sidebar visibility):
1. `Command Palette` — shortcut `⇧⌘P`
2. Separator
3. `Toggle Sidebar` (label reflects current sidebar mode per `sidebar-mode-state` requirements) — shortcut `⇧⌘S`
4. `Focus Sidebar` — shortcut `⌘0`

Group 2 (sidebar content controls):
5. Separator
6. `Collapse All Workspaces`
7. `Expand All Workspaces`
8. `Clear Sidebar Filters`

Group 3 (workspace focus):
9. Separator
10. `Focus Pinned Workspace` — shortcut `⌘\`

The system-provided items SwiftUI adds to the View menu (toolbar/sidebar controls when applicable) SHALL appear alongside Hootty's items; exact system placement is managed by SwiftUI.

#### Scenario: View menu lists palette and sidebar controls

- **WHEN** the user opens the `View` menu
- **THEN** the Hootty items listed above appear in the specified order and invoking each dispatches the corresponding `AppCommand` through `CommandRegistry`

#### Scenario: Toggle Sidebar label tracks mode

- **WHEN** the sidebar is in `condensed` mode
- **THEN** the `View` menu item for toggling the sidebar displays "Hide Sidebar" (per `sidebar-mode-state`)

### Requirement: Workspace Menu Contents

The menu bar SHALL contain a top-level `Workspace` menu (rendered via `CommandMenu("Workspace")`) containing, in order, with separators between groups:

Group 1 (workspace lifecycle):
1. `New Workspace` — shortcut `⌘T`
2. `Close Workspace` (no shortcut)

Group 2 (splits):
3. Separator
4. `Split Right` — shortcut `⌘D`
5. `Split Down` — shortcut `⇧⌘D`
6. `Split Left` — shortcut `⌥⌘D`
7. `Split Up` — shortcut `⌥⇧⌘D`
8. `Equalize Splits` — shortcut `⌃⇧=`

Group 3 (workspace navigation):
9. Separator
10. `Next Workspace` (no shortcut)
11. `Previous Workspace` (no shortcut)

Group 4 (pane focus navigation):
12. Separator
13. `Focus Pane Up` — shortcut `⌥⌘↑`
14. `Focus Pane Down` — shortcut `⌥⌘↓`
15. `Focus Pane Left` — shortcut `⌥⌘←`
16. `Focus Pane Right` — shortcut `⌥⌘→`

Group 5 (pane marking):
17. Separator
18. `Note Pane` — shortcut `⌃⇧F`
19. `Flag Pane` — shortcut `⌃⇧G`

Group 6 (pin + refresh):
20. Separator
21. `Pin/Unpin Workspace` (no shortcut)
22. `Refresh Terminal` (no shortcut)

#### Scenario: Workspace menu replaces Shell menu

- **WHEN** the app launches
- **THEN** a menu titled `Workspace` appears in the position previously occupied by `Shell` and no menu titled `Shell` is present

#### Scenario: All listed commands are present

- **WHEN** the user opens the `Workspace` menu
- **THEN** each of the 22 items listed above appears in the specified order with the specified keyboard shortcut (if any) and invoking each dispatches the corresponding `AppCommand` through `CommandRegistry`

#### Scenario: Close Workspace has no shortcut

- **WHEN** the user opens the `Workspace` menu
- **THEN** the `Close Workspace` entry displays no keyboard shortcut label, and pressing `⇧⌘W` does not invoke it (ghostty's `close_window` action is unchanged)

#### Scenario: Next/Previous Workspace have no shortcut

- **WHEN** the user opens the `Workspace` menu
- **THEN** the `Next Workspace` and `Previous Workspace` entries display no keyboard shortcut labels

### Requirement: Workspace Menu Disabled States

Menu items whose targets cannot act MUST be disabled:

- `Close Workspace` — disabled when `AppModel.selectedWorkspace` is `nil`.
- `Next Workspace` / `Previous Workspace` — disabled when fewer than two workspaces exist in the active profile.
- `Pin/Unpin Workspace` — disabled when `AppModel.selectedWorkspace` is `nil`.

Split, pane focus, equalize, note, and flag commands MAY remain enabled even when no focused pane exists; their handlers already guard with `guard let`.

#### Scenario: Close Workspace disabled with no selection

- **WHEN** no workspace is selected (e.g., all workspaces deleted)
- **THEN** the `Close Workspace` menu item is disabled

#### Scenario: Next Workspace disabled with single workspace

- **WHEN** the active profile contains exactly one workspace
- **THEN** the `Next Workspace` and `Previous Workspace` menu items are disabled

### Requirement: Refresh Branches Command Removed

The `refreshBranches` case SHALL be removed from `AppCommand`. No menu item, palette entry, or handler SHALL reference it.

#### Scenario: AppCommand no longer contains refreshBranches

- **WHEN** the `AppCommand` enum is inspected
- **THEN** no `refreshBranches` case exists and `AppCommand.allCases` does not include it

#### Scenario: Command palette does not list Refresh Branches

- **WHEN** the user opens the command palette
- **THEN** no entry titled `Refresh Branches` is present

### Requirement: Truthful Shortcut Hints

The `AppCommand.shortcutHint` map SHALL only contain entries for commands whose keyboard shortcuts are actually wired — either via `.keyboardShortcut()` on a menu button in `.commands`, or via an explicit exception in `TerminalSurfaceView+Keyboard.swift`. Specifically, the hints for `nextWorkspace` (`⌃⇥`) and `previousWorkspace` (`⌃⇧⇥`) SHALL be removed because those keys are handled by ghostty's default `next_tab`/`previous_tab` bindings and are not intercepted for Hootty workspace switching.

#### Scenario: No phantom shortcut hints

- **WHEN** the command palette is opened
- **THEN** the entries for `Next Workspace` and `Previous Workspace` display no shortcut label

#### Scenario: Remaining shortcut hints match wiring

- **WHEN** any `AppCommand` with a non-nil `shortcutHint` is inspected
- **THEN** the corresponding shortcut is wired as an active menu button shortcut or an explicit handler in `TerminalSurfaceView+Keyboard.swift`

### Requirement: Attention Sounds in App Menu

The `Attention Sounds...` command SHALL be exposed in the `Hootty` app menu (rendered via `CommandGroup(replacing: .appSettings)`), positioned after `Edit Configuration...` with a separator between them. The command SHALL NOT appear in any other menu.

#### Scenario: Attention Sounds in Hootty menu

- **WHEN** the user opens the `Hootty` application menu
- **THEN** the entry `Attention Sounds...` is present after `Edit Configuration...` separated by a menu divider, and invoking it dispatches `AppCommand.attentionSounds` through `CommandRegistry`

#### Scenario: Attention Sounds not in other menus

- **WHEN** the user opens the `View`, `Workspace`, or `Profile` menus
- **THEN** no entry titled `Attention Sounds...` is present
