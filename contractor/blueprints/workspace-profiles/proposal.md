## Why

Heavy Hootty users accumulate many workspaces across unrelated contexts (work, personal projects, client engagements, experiments), and a single flat sidebar becomes noisy and hard to navigate. Users need a way to scope their workspace list, theme, and sidebar state to a named context and switch between them cleanly — without cross-contamination, without running unrelated shells in the background, and without losing any state when they return.

## What Changes

- Add **profiles**: named, isolated sets of workspaces plus per-profile configuration (theme, fonts, sounds, sidebar state). Exactly one profile is active at a time.
- Switching profiles behaves like closing and reopening Hootty: the active profile's surfaces are torn down, state is saved to disk, and the target profile is hydrated from disk. No background PTYs, no cross-profile attention routing, no shared in-memory state between profiles.
- Profiles are mutually unaware: a profile never references, observes, or receives events from another profile. The only cross-profile concept is the `profiles.json` metadata file that lists which profiles exist and which is active.
- New top-level **Profile** menu in the macOS menu bar:
  - Dynamic list of profiles with a checkmark on the active one (`Picker.inline` semantics)
  - New Profile…, Rename Current Profile…, Delete Current Profile… — each prompts via a standard AppKit `NSAlert` with an accessory text field
  - Delete is disabled when only one profile exists
- Active profile name displayed in the custom titlebar next to the traffic lights, so users always know which world they are in.
- Command palette gains dynamic "Switch to Profile: &lt;name&gt;" entries (via existing `CommandRegistry.setSupplementaryCommands`) plus static commands for new/rename/delete.
- New profiles start empty and hit the existing first-launch empty-state code path: one auto-created workspace, default config content copied from `ConfigFile.defaultConfigContent()`.
- **BREAKING (storage layout)**: the root-level `config` and `workspaces.json` move into `profiles/&lt;uuid&gt;/`. Migrated automatically on first launch from the pre-profiles layout; the operation is idempotent and non-destructive.

## Capabilities

### New Capabilities

- `profile-model`: the `Profile` value type, the list-of-profiles state on `AppModel`, the active-profile identifier, and the CRUD operations (create with default name/config, rename, delete with single-profile guard).
- `profile-persistence`: the on-disk directory layout (`profiles.json` + `profiles/&lt;uuid&gt;/{config,workspaces.json}`), the one-shot migration from the pre-profiles layout, and the per-profile `ConfigFile` / `WorkspaceStore` factories that direct reads and writes into the active profile's directory.
- `profile-switching`: the end-to-end switch flow (save current snapshot → tear down all cached surface views → swap `AppModel` workspace/sidebar state → swap the active `ConfigFile` → `GhosttyApp.reloadConfig` → SwiftUI re-renders surfaces) and the invariants it must preserve (no dangling `ghostty_surface_t`, no stale `focusedSurface`, no cross-profile pane IDs leaking into caches).
- `profile-menu`: the macOS top-level Profile menu with the dynamic profile list, the AppKit `NSAlert` helpers for new/rename/delete, the active-profile checkmark rendering, the disabled-when-only-one-profile delete guard, and the dynamic command palette entries for profile switching.
- `profile-titlebar`: the active profile name display in `ContentView.titleBar`, positioned immediately after the reserved traffic-light space, with typography and color derived from `DesignTokens`.

### Modified Capabilities

- None. Existing requirements (workspaces, sidebar, pin-workspace, workspace-collapse, sidebar-badge-filters, sound-playback, etc.) all continue to operate against `AppModel.workspaces` unchanged. Their spec-level behavior is unaffected — they simply happen to be scoped to whichever profile is active. No delta specs required.

## Impact

**New code**
- `Sources/HoottyCore/Profile.swift` — the `Profile` struct and `ProfileList` / metadata state.
- `Sources/HoottyCore/ProfileStore.swift` — reads and writes `profiles.json`, owns migration, and produces per-profile `ConfigFile` and `WorkspaceStore` instances on demand.
- `Sources/Hootty/NSAlertPrompt.swift` (or similar) — small AppKit helper wrapping `NSAlert` with an accessory text field for name prompts.

**Modified code**
- `Sources/HoottyCore/AppModel.swift` — gains `profiles`, `activeProfileID`, and `switchProfile(to:)` / `createProfile(...)` / `renameProfile(...)` / `deleteProfile(...)`; `init` reads the active profile via `ProfileStore` instead of the bare `WorkspaceStore`.
- `Sources/HoottyCore/AppCommand.swift` — new static commands for new/rename/delete profile.
- `Sources/Hootty/HoottyApp.swift` — new `CommandMenu("Profile")` block with dynamic `Picker.inline`, wires command handlers through `CommandRegistry`, and registers dynamic "Switch to Profile: &lt;name&gt;" supplementary commands.
- `Sources/Hootty/CommandRegistry.swift` — handlers for the new profile commands.
- `Sources/Hootty/Views/ContentView.swift` — `titleBar` computed view gains the active profile name `Text`, positioned after the 78pt traffic-light spacer.

**Unchanged**
- `Workspace`, `Pane`, `SplitNode`, `WorkspaceStore` snapshot type, `GhosttyApp`, `GhosttyApp+Actions`, `PaneEventHandler`, surface lifecycle, all `ghostty_*` callback routing, Metal rendering, and every view that deals with panes or splits. The terminal pipeline does not change at all.

**Persistence / migration**
- On first launch after upgrade: if `profiles.json` is absent but root-level `config` and/or `workspaces.json` exist, create `profiles/&lt;new-uuid&gt;/`, move both files into it, and write `profiles.json` with that profile as the only entry, named "Default", marked active. If neither legacy file exists, write a fresh `profiles.json` with an empty-but-active "Default" profile whose directory is created lazily on first workspace save.
- Operation is idempotent: running migration when `profiles.json` already exists is a no-op.
- DEBUG and release paths (`Hootty-Dev` vs `Hootty` app-support dirs) both participate.

**Dependencies**
- No new third-party dependencies. Reuses `ConfigFile`, `WorkspaceStore`, `GhosttyApp.reloadConfig`, existing `CommandRegistry` supplementary-command mechanism, and standard `NSAlert`.

**Risk areas**
- State-swap ordering during switch must not leave dangling `ghostty_surface_t` pointers or a stale `focusedSurface`.
- Migration must run exactly once and must not clobber a partially-created new-format layout (e.g., a crash mid-migration on a prior launch).
- Dynamic Profile menu must re-render whenever the profile list or active profile changes; `@Observable` propagation from `AppModel` into `.commands` blocks has to be verified.
- Per-profile `ConfigFile` swap must correctly propagate theme changes via `ThemeManager` and `GhosttyApp.reloadConfig` in the right order so there is no flash of wrong theme during the switch.
