## Why

The AppKit menu bar has accumulated cruft and usability paper cuts that undermine the macOS-native feel of the app. The most visible symptom is two "View" menus side-by-side — SwiftUI auto-injects one and `CommandMenu("View")` creates a second — but there are also registered commands that never surface in any menu, a nearly-empty `Theme` menu that exists for a single action, and shortcut hints in the command palette that are outright fiction because the keys are never wired. This is the moment to do a single cleanup pass rather than keep piling onto a structure that was never designed holistically.

## What Changes

- **BREAKING (menu layout):** Collapse the duplicate `View` menu by merging custom items into SwiftUI's auto-generated `View` menu via `CommandGroup(after:)`, so only one `View` menu appears in the menu bar.
- **BREAKING (menu layout):** Rename the `Shell` menu to `Workspace` and consolidate all workspace-level and pane-level actions into it (splits, pane focus navigation, note/flag, plus previously palette-only commands).
- **BREAKING (menu layout):** Remove the top-level `Theme` menu entirely. Theme selection remains reachable via the command palette (`changeTheme` AppCommand stays registered).
- Surface currently palette-only commands in the menu bar so they are discoverable without invoking the palette:
  - `Close Workspace`, `Next Workspace`, `Previous Workspace`, `Pin/Unpin Workspace`, `Collapse All Workspaces`, `Expand All Workspaces`, `Clear Sidebar Filters`, `Note Pane`, `Refresh Terminal`.
- Move `Attention Sounds…` into the `Hootty` app menu (next to `Edit Configuration…`), matching macOS convention for settings-style modals.
- **BREAKING (command removal):** Delete the `refreshBranches` case from `AppCommand` and its empty handler in `HoottyApp.registerCommands()`. The command is dead (the handler comment says branches are computed on demand).
- Drop fictional shortcut hints: `nextWorkspace` (`⌃⇥`) and `previousWorkspace` (`⌃⇧⇥`) advertise shortcuts in the command palette but are never wired as menu shortcuts or ghostty overrides. Remove the hints from `AppCommand.shortcutHint` so the palette stops lying to users.
- Do not add new keyboard shortcuts for `Close Workspace`, `Next Workspace`, or `Previous Workspace`. Leave them as menu-only entries to avoid introducing new ghostty keybinding overrides.

## Capabilities

### New Capabilities
- `menu-bar-structure`: Top-level macOS menu bar layout — the set of menus, their titles, their ordering, and the commands each contains. Covers the View merge, Theme removal, Shell→Workspace rename, and surfacing of previously palette-only commands.

### Modified Capabilities
- `profile-menu`: The Menu Placement requirement currently says the Profile menu is placed "after the `View` menu in natural order." After this change, Profile is placed after the `Workspace` menu, not immediately after `View`. Delta updates the placement clause.

(The `attention-sounds-command` capability is unchanged at the spec level — its Overview still accurately describes the command as reachable from "the command palette and menu bar." The specific menu placement is owned by `menu-bar-structure`, which covers the whole bar layout and includes a dedicated requirement for where Attention Sounds sits.)

## Impact

**Code:**
- `Sources/Hootty/HoottyApp.swift` — `.commands { }` block restructured; `CommandMenu("View")` replaced with `CommandGroup(after: .sidebar)`; `CommandMenu("Theme")` deleted; `CommandMenu("Shell")` renamed to `CommandMenu("Workspace")` and repopulated; `CommandGroup(replacing: .appSettings)` extended with the `Attention Sounds…` entry; dead `refreshBranches` handler removed.
- `Sources/HoottyCore/AppCommand.swift` — `refreshBranches` case removed from the enum, `title` switch, and `AppCommand.allCases` usage audited; `shortcutHint` entries for `nextWorkspace` and `previousWorkspace` removed.
- `Tests/HoottyCoreTests/` — any test that asserts `AppCommand.allCases` length or iterates the enum may break; `AppCommandTests` or similar must be updated.

**APIs:** None exposed externally. The `AppCommand` enum is used internally by `CommandRegistry` only.

**Dependencies:** No new dependencies.

**User-visible behavior:** Menu bar layout changes. Keyboard shortcuts for existing Hootty menu items are unchanged. The palette continues to list all registered commands (minus `refreshBranches`, minus misleading hints).

**Systems:** None. Ghostty keybinding exception list in `TerminalSurfaceView+Keyboard.swift` is intentionally untouched — no new entries needed because we avoided adding shortcuts that would collide with ghostty defaults.
