## Context

Today, Hootty stores a single flat list of workspaces. `AppModel` owns `workspaces: [Workspace]`, `WorkspaceStore` persists a single `WorkspaceSnapshot` to `~/Library/Application Support/Hootty[-Dev]/workspaces.json`, and `ConfigFile` stores theme/font/sound settings in a sibling `config` file. The ghostty runtime (`GhosttyApp.shared`, a singleton wrapping `ghostty_app_t`) is initialized once from that `ConfigFile` and supports live config reloads via `ghostty_app_update_config` (already invoked by the theme picker at `ContentView.swift:414`).

Users who juggle multiple contexts (work, personal, client engagements) want to scope their workspace list, theme, and sidebar state to a named context and switch between them. The explored design landed on a "cold swap" model: exactly one profile is active at a time, switching is semantically equivalent to closing and reopening the app (but in-process), and profiles are mutually invisible — no background PTYs, no cross-profile attention, no cross-profile state.

Constraints identified during exploration:
- `ghostty_app_t` is a singleton and supports in-place config swap, so we do not need to rebuild the ghostty runtime.
- `WorkspaceStore` and `ConfigFile` both accept a custom `fileURL` in `init`, so per-profile stores are a pure factory concern.
- `AppModel` is `@Observable` and `@MainActor`; all state mutations propagate through SwiftUI automatically.
- Per-`@Observable` class the pattern is to swap internal fields (not replace the `AppModel` instance), because replacing the root model triggers a full view-tree rebuild with new identity.
- `GhosttyApp.surfaceViews`, `pendingParentSurfaces`, and `pendingCommands` must be emptied of stale entries on switch to avoid dangling callbacks and leaked native resources.

## Goals / Non-Goals

**Goals**

- Isolate workspace list, sidebar state, and full config (theme, font, sounds) per profile.
- Provide switch, create, rename, and delete operations through a native top-level `Profile` menu with standard `NSAlert` prompts.
- Show the active profile name in the custom titlebar so users always know which world they are in.
- Dynamically populate command palette entries for profile switching.
- Migrate existing installs from the root `config` + `workspaces.json` layout into `profiles/<uuid>/` on first launch, idempotently.
- Contain the blast radius: no changes to `Workspace`, `Pane`, `SplitNode`, `GhosttyApp` callback machinery, or the surface rendering pipeline.

**Non-Goals**

- Running multiple profiles simultaneously (no background PTYs, no multi-window-per-profile).
- Per-profile overrides on top of a global config (profiles own their full config wholesale; no merge logic).
- Cross-profile attention, notifications, or command routing (profiles never observe each other).
- Drag-and-drop of workspaces or panes between profiles.
- Importing/exporting profiles as a deliberate user flow (directory copy should work but is not a first-class feature).
- Per-profile keyboard shortcuts or command bindings.
- Undoing a profile deletion (delete is permanent after confirm).

## Decisions

### Decision: Cold-swap profile switching over live background profiles

We tear down the active profile's surfaces on switch and hydrate the target from disk, mirroring close-and-reopen semantics.

**Alternatives considered**
- *Live background profiles (Arc-style)*: Every profile keeps its PTYs alive in memory. Gives instant switching but multiplies memory/CPU by profile count, forces per-profile attention routing, and complicates callback lookups (`findPane` would have to scan across profiles). For a terminal, the memory cost of background shells is meaningful, and the "which profile pinged me" UX is a sizeable surface on its own.
- *Literal quit-and-relaunch*: Guaranteed clean state, zero in-memory bugs. But feels heavyweight for a "switch view" action and loses window position/frame restoration ergonomics that a SwiftUI app handles naturally.

**Rationale**: The user explicitly asked for "like closing and reopening Hootty" behavior without the literal relaunch cost. Cold swap gives that with zero new runtime concepts — every step (`cleanupWorkspace`, `reloadConfig`, `WorkspaceSnapshot` load) already exists.

### Decision: Directory-per-profile persistence layout

Each profile gets a directory at `profiles/<uuid>/` containing a `config` file and a `workspaces.json` file. A top-level `profiles.json` at the app-support root tracks metadata (`{activeProfileID, profiles: [{id, name}]}`).

**Alternatives considered**
- *Single `profiles.json` holding everything*: Simpler one-file layout, but bloats the metadata file, forces a new Codable shape for the nested workspace snapshots, and makes "which profile is which on disk" hard to debug by hand.
- *Flat files like `workspaces-<uuid>.json` and `config-<uuid>`*: Same number of files but harder to scan and tempts future code into reading the wrong one.

**Rationale**: Directory-per-profile reuses the existing `WorkspaceSnapshot` Codable shape verbatim inside each profile directory and reuses `ConfigFile(fileURL:)` without modification. Migration is a simple file move. Future features like per-profile export become a directory copy.

### Decision: Entire `ConfigFile` is per-profile, nothing is shared

Each profile owns a complete `ConfigFile` — theme, font, scrollback, sounds, and every `hootty-*` key. There is no two-tier merging of "profile config over global config".

**Alternatives considered**
- *Per-profile theme only, rest global*: Would have to single out which keys are per-profile and which are shared, maintain two `ConfigFile` instances, and merge them before feeding ghostty. Splits mental model: "why does my bell-sound stick but my thumbnails preference doesn't?"
- *Per-profile overrides layered on a shared base*: More flexible but requires resolution logic, diffing on save, and new bugs at the boundary.

**Rationale**: The user asked for "like reopening Hootty" behavior. If profiles literally own their full config, no merge logic exists to be buggy. The cost is minor: if a user wants the same setting across profiles, they set it twice. The `ConfigFile` type already supports `init(fileURL:)` and has no hidden global state, so this costs nothing architecturally.

### Decision: In-place state swap on the existing `AppModel` instance

On profile switch, we mutate fields on the existing `AppModel` (`workspaces`, `selectedWorkspaceID`, `collapsedWorkspaceIDs`, `pinnedWorkspaceID`, `activeSidebarFilters`, `workspaceStore`, `configFile`) rather than replacing the `AppModel` instance. `HoottyApp` continues to hold the same `@State appModel`.

**Alternatives considered**
- *Replace the entire `AppModel`*: Would require `HoottyApp` to swap the `@State` value, which changes root view identity and triggers a full rebuild. Would also re-run `AppModel.init`'s setup of `PaneEventHandler` and workspace-load logic, doubling work that is irrelevant to the switch.

**Rationale**: `@Observable` is designed for in-place mutation. Fewer moving parts, no view-identity churn, no risk of stale observers holding references to a defunct `AppModel`.

### Decision: Top-level `Profile` menu with `Picker.inline` for the profile list

The profile list renders as a SwiftUI `Picker` with `.pickerStyle(.inline)` bound to `appModel.activeProfileID`. This gives automatic checkmark-on-selected semantics and a clean `ForEach` over profiles. Below a `Divider()`, three static `Button`s invoke new/rename/delete commands.

**Alternatives considered**
- *View → Profile submenu*: The user proposed this. Viable but buries a first-class concept under View (which today handles sidebar visibility and zoom). A dedicated menu matches the precedent of iTerm2 and Terminal.app and is more discoverable.
- *Manual menu items with conditional title prefix ("✓ Work")*: Works but forgoes SwiftUI's built-in selection semantics and requires manual state tracking.

**Rationale**: `Picker.inline` is the shortest path to correct rendering of a radio-button-style list inside a menu and automatically updates when `profiles` changes. Placing it as a top-level `CommandMenu` treats profiles as a first-class concept.

### Decision: Profile name prompts via standard `NSAlert`

New/rename/delete commands open a standard AppKit `NSAlert` with an accessory `NSTextField` (or a confirmation-only alert for delete). A small helper `NSAlertPrompt.swift` in the Hootty app layer wraps the repeated boilerplate.

**Alternatives considered**
- *SwiftUI `.sheet` with a custom view*: More consistent with the rest of the app's modal UI (`CommandPaletteView`, `ThemePickerView`) but heavier — needs a dedicated view file, a `@State` binding, and plumbing through `ModalState`. Overkill for a name prompt.
- *Inline editable menu item*: Not natively supported by AppKit menus; would require custom menu item view classes.

**Rationale**: The user explicitly said "let AppKit handle it." `NSAlert` with an accessory view is the canonical macOS pattern for a one-shot name input and requires ~20 lines of code per prompt.

### Decision: Titlebar profile name is a plain `Text` inserted after the traffic-light spacer

We add `Text(appModel.activeProfile?.name ?? "")` directly in `ContentView.titleBar`, right after the existing 78pt `Color.clear.frame(width: 78)`, using `TypeScale.bodySize` and a token-derived muted color. No new views, no new types.

**Rationale**: The titlebar is already an `HStack` with exactly the shape we need. `@Observable` propagation from `appModel.activeProfileID` through `appModel.activeProfile` (a computed property) will trigger `Text` re-rendering automatically on switch or rename.

### Decision: Migration is eager, one-shot, and guarded by `profiles.json` existence

On launch, `ProfileStore` checks whether `profiles.json` exists. If not, it looks for root-level `config` and/or `workspaces.json`. If either exists, it runs a one-shot migration that generates a new UUID, creates `profiles/<uuid>/`, moves the files in, and writes `profiles.json`. If a partial `profiles/` directory from an earlier crash exists, migration refuses to overwrite it and logs an error.

**Alternatives considered**
- *Lazy migration on first config/workspace access*: Scatters migration logic across read paths, risks double-migration in races. Reject.
- *Copy instead of move*: Leaves legacy files on disk as dead weight and forces users to clean up by hand. Reject.

**Rationale**: Eager, one-shot, at-launch migration is simpler to reason about and debug. The idempotency check (`profiles.json` exists → skip) makes it safe to run on every launch.

### Decision: `ProfileStore` factories are the only way to access per-profile stores

`ProfileStore` owns both `profiles.json` I/O and the creation of per-profile `WorkspaceStore` and `ConfigFile` instances via factory methods (`workspaceStore(for profileID:)`, `configFile(for profileID:)`). `AppModel` never computes profile directory paths directly.

**Rationale**: Encapsulates the "a profile is a directory, and a directory produces two stores" invariant in exactly one place. If the layout changes later (e.g., subdirectories for multiple snapshots), only `ProfileStore` changes.

### Decision: Active profile name defaults to "Default" on migration; user can rename

The first-migrated profile is called "Default". No attempt is made to guess a better name (e.g., from `$USER` or workspace names).

**Rationale**: Neutral, unambiguous, matches the user's mental model of "this is what I had before". Renaming is trivial via the new command.

## Risks / Trade-offs

- **Risk**: Dangling `ghostty_surface_t` pointers or stale `focusedSurface` across a switch could crash ghostty callbacks. → **Mitigation**: The switch ordering invariant (save → teardown → swap → reload → activate) runs teardown synchronously before mutating `workspaces`. `GhosttyApp.cleanupWorkspace` already handles removing cached views, clearing `pendingParentSurfaces`, and nilling `focusedSurface`. Add an explicit post-condition check (assert or `Log.warning`) after teardown that `surfaceViews.isEmpty` and `focusedSurface == nil`.

- **Risk**: Migration runs partially, leaves the filesystem in a half-migrated state. → **Mitigation**: Do the file moves before writing `profiles.json`, and write `profiles.json` atomically (`.atomic` flag). If a crash happens mid-move, a subsequent launch sees no `profiles.json` but sees the partial `profiles/` directory; the recovery branch logs the issue and either completes the migration by reusing the existing profile directory if one is present, or refuses and exits early so the user sees a clean error in logs rather than silent data loss.

- **Risk**: Theme flash during switch (old theme rendered briefly before new config takes effect). → **Mitigation**: Strict ordering — swap `ConfigFile`, call `ghostty_app_update_config`, then update `ThemeManager` (which drives `DesignTokens`) before mutating `workspaces`. The first SwiftUI render pass after the switch sees the new theme and creates surfaces with it.

- **Risk**: `@Observable` `.commands` blocks may not re-render dynamically when `profiles` changes. → **Mitigation**: Tested pattern already exists for dynamic theme commands (`CommandRegistry.setSupplementaryCommands`). Use the same pattern for the palette. For the menu itself, bind the `Picker` directly to `appModel.activeProfileID` with `ForEach(appModel.profiles)` inside — SwiftUI observes the underlying `@Observable` fields and re-renders automatically.

- **Risk**: Duplicate profile names confuse users. → **Mitigation**: `createProfile(named:)` uses the same numeric-suffix disambiguation as `AppModel.nextWorkspaceName()`. Renaming allows duplicates (we do not dedupe after the fact) — acceptable because the UUID is the identity and the user explicitly chose the name.

- **Risk**: Trade-off: profiles lose ephemeral state on switch (repl history, running processes). → **Accepted**: This is the explicit semantics the user asked for. Documentation (in `profile-switching/spec.md`) makes it clear.

- **Risk**: Per-profile config duplication — users have to set shared preferences in each profile. → **Accepted**: This is the cost of not having merge logic, and the number of settings is small. A future "copy settings from profile X" command could mitigate if it becomes painful.

- **Risk**: Deletion is permanent. → **Mitigation**: Confirmation dialog is warning-styled and names the profile being deleted. `NSAlert` default button is Cancel to prevent accidental confirm-on-Enter.

## Migration Plan

1. **In-code migration (one-shot, at launch)**
   - `ProfileStore.init` (or a dedicated `migrateIfNeeded()` helper) runs before `AppModel` loads any workspaces.
   - If `profiles.json` exists → no-op, proceed.
   - If `profiles.json` does not exist and legacy `config` or `workspaces.json` exist at the root:
     1. Generate a new UUID.
     2. Create `profiles/<uuid>/` (fail if it already exists).
     3. Move `config` → `profiles/<uuid>/config` (if present).
     4. Move `workspaces.json` → `profiles/<uuid>/workspaces.json` (if present).
     5. Atomically write `profiles.json` with `{activeProfileID: <uuid>, profiles: [{id: <uuid>, name: "Default"}]}`.
   - If `profiles.json` does not exist and no legacy files exist → write a bare `profiles.json` with a single "Default" profile whose directory will be created lazily by `AppModel` first-launch empty-state path.

2. **Rollback strategy**: If a user wants to go back to the pre-profiles layout, they can move `profiles/<their-default-uuid>/config` and `workspaces.json` back to the app-support root and delete `profiles.json`. No tooling is provided — this is a manual recovery path for debugging, not a supported flow.

3. **DEBUG vs release**: Migration runs independently in both `Hootty-Dev/` and `Hootty/` app-support directories. They never share state.

4. **Backwards compatibility**: The `WorkspaceSnapshot` Codable shape is unchanged, so a profile's `workspaces.json` is identical to the pre-profiles `workspaces.json`. Downgrading the app (uninstall new, install old) requires the manual rollback above.

## Open Questions

- **Keyboard shortcut for switching**: Do we want `⌘⇧[` / `⌘⇧]` (cycle previous/next profile) shortcuts, or only menu/palette access? Not strictly needed for v1; easy to add later as two more `AppCommand` cases.
- **First-run UX for the Profile menu**: Should we guide the user to the menu on first launch (e.g., a tooltip the first time the titlebar profile label appears)? Probably not for v1 — AppKit menu discovery is a standard macOS idiom.
- **Deletion recovery window**: Should delete move the profile directory to a `.trash/` folder inside app-support for an undelete window? Declined in the decisions above, but worth revisiting if users report regret.
- **Window restoration across launches**: Does `NSWindow` frame restoration interact with the profile active at launch? Investigate during task breakdown; likely a non-issue since window frame is a global AppKit concern, not per-profile.
