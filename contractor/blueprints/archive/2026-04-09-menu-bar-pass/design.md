## Context

The current `.commands { }` block in `Sources/Hootty/HoottyApp.swift:397-523` is the entire menu bar authoring surface. It currently declares:

- `CommandGroup(replacing: .appSettings)` — holds `Edit Configuration…` with `⌘,`.
- `CommandMenu("View")` — adds a second top-level View menu next to SwiftUI's auto-injected one.
- `CommandMenu("Profile")` — profile switcher, create, rename, delete.
- `CommandMenu("Shell")` — workspace creation + splits + flag + pane focus.
- `CommandMenu("Theme")` — single entry, nothing else.

All dispatch goes through `commandRegistry.execute(.foo)`, so the menu layer is a thin view on top of `AppCommand`. The real refactor is SwiftUI-level; the command registry and handlers are untouched except for the `refreshBranches` removal and the `shortcutHint` cleanup.

Ghostty is present in this picture only as a keyboard-binding consumer. Its surface view intercepts keys via `handlePerformKeyEquivalent` before SwiftUI menus see them. This change intentionally avoids adding any new shortcuts that would require extending the exception list in `TerminalSurfaceView+Keyboard.swift`.

## Goals / Non-Goals

**Goals:**
- Eliminate the duplicate `View` menu symptom.
- Remove the near-empty `Theme` menu.
- Give every non-destructive registered `AppCommand` a home in the menu bar, so the command palette isn't the only way to discover functionality.
- Rename `Shell` → `Workspace` for consistency with the app's vocabulary (workspaces are the primary unit; "Shell" was a borrowed Terminal.app term).
- Make disabled states accurate (Close/Next/Previous disabled when they can't act).
- Delete dead code: `refreshBranches` case + handler; phantom `shortcutHint` entries.

**Non-Goals:**
- Changing any existing keyboard shortcut. Every shortcut currently wired in Hootty's menus stays bound to the same key combo.
- Adding new keyboard shortcuts that would require a ghostty keybinding exception. `Close Workspace`, `Next Workspace`, `Previous Workspace` are menu-only.
- Refactoring `CommandRegistry` or `AppCommand` beyond the `refreshBranches` deletion.
- Touching ghostty's keybinding system or `TerminalSurfaceView+Keyboard.swift`.
- Adding new `AppCommand` cases. Every menu entry added in this pass maps to a command that is already registered (and already palette-reachable).
- Reshuffling the command palette. The palette automatically picks up changes from `AppCommand` + `shortcutHint`.

## Decisions

### D1: Use `CommandGroup(after: .sidebar)` to merge into the auto-generated View menu

**Choice:** Replace `CommandMenu("View") { … }` with `CommandGroup(after: .sidebar) { … }`.

**Rationale:** SwiftUI's auto-generated `View` menu contains a `.sidebar` anchor (used for the system's toolbar/sidebar toggle items when applicable). Placing our items `after: .sidebar` positions them below the system-injected controls and keeps them in the same top-level `View` menu — which is the entire point of this pass.

**Alternatives considered:**
- `CommandGroup(replacing: .sidebar)` — would wipe any system-provided sidebar controls. Rejected: SwiftUI may add useful system items (e.g., toolbar toggles) in future macOS versions and we shouldn't preemptively delete them.
- `CommandGroup(after: .toolbar)` — also valid, but `.sidebar` is semantically closer to what the View menu items do (sidebar toggle, focus, content controls).
- Leaving `CommandMenu("View")` and living with the duplicate — rejected: this is the whole problem.

### D2: One big `Workspace` menu (option (a)) instead of split Workspace + Shell (option (b))

**Choice:** Rename `Shell` → `Workspace` and consolidate workspace-level and pane-level actions into one menu.

**Rationale:** Panes live inside workspaces in Hootty's model. Splitting into two menus creates a fuzzy boundary (is "Focus Pane" a workspace or shell concern?) and adds another top-level menu without adding clarity. The existing Shell menu already mixes workspace creation (`New Workspace`) with pane actions (`Split Right`), so consolidation is closer to the current intent anyway. Single-menu discoverability is better for an app with ~15 actions at this level.

**Alternatives considered:**
- Two menus: `Workspace` (lifecycle + nav + pin) and `Shell` (splits + pane focus + note/flag). Rejected as above.
- Keep `Shell` name, just add missing commands. Rejected because "Shell" doesn't match the rest of the app's vocabulary (sidebar, command palette, docs all say "workspace").

### D3: No keyboard shortcuts for `Close Workspace`, `Next Workspace`, `Previous Workspace`

**Choice:** Menu-only. No `.keyboardShortcut()` modifier.

**Rationale:** The obvious shortcuts conflict with ghostty defaults:
- `⇧⌘W` → ghostty's `close_window`
- `⌃⇥` / `⌃⇧⇥` → ghostty's `next_tab` / `previous_tab`

Adding these Hootty-side requires extending the exception list in `TerminalSurfaceView+Keyboard.swift` (the `⌘0` pattern) — which is extra plumbing, extra surface for bugs, and pulls us out of the ghostty default experience without a strong reason. Users who want keyboard access already have the command palette (`⇧⌘P`).

**Alternatives considered:**
- Use `⌃⇧W`, `⌃⇧⇥`, etc. (unused in ghostty). Rejected because they break convention (⌃⇧· is the "Hootty extra actions" family used by Flag/Note, not navigation).
- Add ghostty exceptions. Rejected: explicit non-goal for this pass.

### D4: Delete `refreshBranches` rather than mark deprecated

**Choice:** Remove the `refreshBranches` case from `AppCommand` entirely, along with its empty handler in `HoottyApp.registerCommands()`.

**Rationale:** The handler is a no-op with a comment explaining that branches are computed on demand (`HoottyApp.swift:171-173`). The command has no menu entry and shipping a do-nothing palette entry is user-hostile. `AppCommand` is an internal enum with no stability contract, so removal is safe.

**Alternatives considered:**
- Keep the case, remove it from the palette by not registering a handler. Rejected: the enum case itself becomes dead code and confuses future contributors.
- Add an `@available(*, deprecated)` annotation. Rejected: this is an internal enum; no external callers exist.

### D5: Drop `shortcutHint` for `nextWorkspace` / `previousWorkspace` rather than wire them

**Choice:** Remove the hint entries from `AppCommand.shortcutHint`. Do not wire the shortcuts.

**Rationale:** The hints currently advertise `⌃⇥` and `⌃⇧⇥` in the palette, but pressing those keys in a focused terminal does nothing Hootty-visible — ghostty consumes them as `next_tab`/`previous_tab`, which operate on ghostty's internal tab model (which Hootty doesn't use). So the palette is lying. Wiring them would require ghostty exceptions (see D3); dropping the hint is the honest fix.

**Alternatives considered:**
- Wire them via exception list. Rejected per D3.
- Leave the lie in place. Rejected — a command palette that displays incorrect shortcuts erodes trust in the whole palette.

### D6: Disabled state via `.disabled()` modifiers bound to `@Observable` model properties

**Choice:** Use `.disabled(appModel.selectedWorkspace == nil)`-style expressions directly on menu buttons.

**Rationale:** `AppModel` is already `@Observable` and passed through `@State` in `HoottyApp`. SwiftUI menu re-evaluation is automatic. No new state or bindings required.

**Alternatives considered:**
- Compute disabled booleans in a helper. Unnecessary indirection for two or three call sites.
- Dynamic command registration. Overkill.

### D7: Attention Sounds placement in the `Hootty` app menu, not a top-level menu

**Choice:** Extend `CommandGroup(replacing: .appSettings)` to contain two buttons: `Edit Configuration…` (existing, `⌘,`) and `Attention Sounds…` (new, no shortcut), separated by a `Divider()`.

**Rationale:** Both are "open a settings-ish modal from the app chrome" operations and macOS HIG places settings-type commands in the app menu. Folding it in matches user expectations (`Hootty ▸ Settings…` pattern) without needing a dedicated menu.

**Alternatives considered:**
- Put it in View. Plausible but semantically wrong — it's a setting, not a view toggle.
- Keep it palette-only. Rejected — the user explicitly picked the Hootty menu option during exploration.

## Risks / Trade-offs

- **[Risk] Existing keyboard muscle memory for `Shell` users** → Mitigation: shortcuts are unchanged; only the menu label differs. `⌘D` still splits right, `⌘T` still makes a workspace, etc.
- **[Risk] SwiftUI `.sidebar` anchor may behave differently across macOS 14/15/16** → Mitigation: the anchor is the documented public API for this purpose; behavior regressions are Apple's problem, not ours. Visual verification of the View menu on macOS 14 is part of the QA checklist.
- **[Risk] Someone adds a new `AppCommand` case and doesn't update `allCases` assertions** → Mitigation: `AppCommand.allCases` is synthesized by `CaseIterable`; no manual list to drift. Tests that count cases should be updated in the same commit as the deletion.
- **[Risk] Users relied on `⌃⇥` for "next workspace" based on the palette hint** → Mitigation: they never actually worked, so no workflow is being broken. Dropping the hint prevents future users from hitting the same dead end.
- **[Trade-off] No `Close Workspace` shortcut at all** → Users who want one can still use the sidebar's close affordance or the command palette. Acceptable cost to avoid the ghostty exception list.

## Migration Plan

1. Create the new menu structure in `HoottyApp.swift` (one commit, all at once — it's a single `.commands` block).
2. Delete `refreshBranches` from `AppCommand` + handler registration.
3. Remove the two phantom `shortcutHint` entries.
4. Update any `HoottyCoreTests` that count `AppCommand` cases or assert specific enum membership.
5. Run `make build`, `swift test`, `make format-check`, `make lint`.
6. Manual verification: launch the app and walk every menu, clicking each item once to confirm it still dispatches. Pay attention to disabled states.

No rollback needed — the change is entirely SwiftUI-layer and reversible by a single revert.

## Open Questions

None. All decisions from the exploration conversation are captured above.
