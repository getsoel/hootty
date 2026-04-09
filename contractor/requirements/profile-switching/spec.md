## ADDED Requirements

### Requirement: Switch Profile Operation

`AppModel` SHALL expose a `switchProfile(to id: UUID)` operation that atomically transitions the running application from the currently active profile to a target profile. The operation MUST be a no-op when the target id equals the current `activeProfileID`.

#### Scenario: Switch to a different profile

- **WHEN** `switchProfile(to:)` is called with an id different from `activeProfileID`
- **THEN** the system saves the current profile snapshot, tears down active surfaces, swaps `AppModel` state for the target profile, reloads the ghostty config, and updates `activeProfileID`

#### Scenario: Switch to the active profile

- **WHEN** `switchProfile(to:)` is called with the currently active profile's id
- **THEN** the operation returns immediately with no state change and no side effects

#### Scenario: Switch to an unknown profile

- **WHEN** `switchProfile(to:)` is called with an id that does not exist in `profiles`
- **THEN** the operation is rejected with no state change

### Requirement: Save Before Switch

Before tearing down state, the system SHALL persist the current profile's workspaces and sidebar state using the same path as `AppModel.saveWorkspaces()`, writing to the current profile's `workspaces.json`.

#### Scenario: Unsaved state is preserved across switch

- **WHEN** the user has made mutations that would normally be saved by `debouncedSave` (e.g., workspace rename, pane pwd change) and then invokes `switchProfile`
- **THEN** those mutations are flushed to the current profile's `workspaces.json` before teardown begins, and are present when the profile is next activated

### Requirement: Surface Teardown Before State Swap

Before mutating `AppModel.workspaces` or swapping the `ConfigFile`, the system SHALL tear down every active terminal surface. This means calling `GhosttyApp.cleanupWorkspace(_:)` for every workspace in the current profile, which frees the underlying `ghostty_surface_t` and clears cached surface views. `GhosttyApp.focusedSurface` MUST be `nil` after teardown and before hydration begins.

#### Scenario: No surfaces leak across switch

- **WHEN** a switch completes
- **THEN** `GhosttyApp.surfaceViews` contains no entries from the previous profile, and `GhosttyApp.focusedSurface` is `nil` until a new surface becomes first responder in the target profile

#### Scenario: Pending state is cleared

- **WHEN** a switch completes
- **THEN** `GhosttyApp.pendingParentSurfaces` and `GhosttyApp.pendingCommands` contain no entries from the previous profile

### Requirement: State Hydration for Target Profile

After teardown, the system SHALL replace `AppModel.workspaces`, `AppModel.selectedWorkspaceID`, `AppModel.collapsedWorkspaceIDs`, `AppModel.pinnedWorkspaceID`, and `AppModel.activeSidebarFilters` with values loaded from the target profile's `workspaces.json`. When the target profile has no `workspaces.json`, the system SHALL hit the first-launch empty-state path (create one default workspace and select it).

#### Scenario: Hydrate from an existing snapshot

- **WHEN** switching to a profile whose `workspaces.json` exists
- **THEN** `AppModel.workspaces` matches the snapshot, `selectedWorkspaceID` is restored from it, and collapsed/pinned/filter state match the snapshot

#### Scenario: Hydrate a brand-new profile

- **WHEN** switching to a profile that has no `workspaces.json` yet
- **THEN** exactly one workspace is created via the existing empty-state code path and is made the selected workspace

### Requirement: Config and Theme Reload on Switch

After workspace state is hydrated, the system SHALL swap `AppModel.configFile` (and therefore `ThemeManager` / `SoundManager`) to a fresh `ConfigFile` bound to the target profile's `config` file, then call `GhosttyApp.reloadConfig(ghosttyContent:)` with the new file contents, then update `ThemeManager` with the resolved theme returned by `reloadConfig`.

#### Scenario: Theme propagates to new surfaces

- **WHEN** switching to a profile whose `config` specifies a different theme than the previous profile
- **THEN** new surfaces created for the target profile render with the new theme from first paint

#### Scenario: Sidebar colors update

- **WHEN** switching to a profile with a different theme
- **THEN** `DesignTokens` derived from `ThemeManager` produce sidebar, titlebar, and chrome colors matching the new theme immediately after the switch

### Requirement: Profiles Do Not Observe Each Other

During and after a switch, the deactivated profile SHALL have no active in-memory state. The system MUST NOT retain surfaces, workspaces, panes, or callback handlers from the previous profile once the switch has completed.

#### Scenario: Previous profile cannot receive events

- **WHEN** a switch has completed from profile A to profile B
- **THEN** no `ghostty_surface_t` for any pane from profile A exists, and `AppModel.findPane(id:)` for any pane id that belonged to profile A returns `nil`

#### Scenario: No background PTYs

- **WHEN** profile B is active
- **THEN** no shell process for any pane from profile A remains running under Hootty's control; profile A's PTYs are terminated by surface teardown

### Requirement: Switch Ordering Invariant

The switch operation SHALL execute its steps in the following fixed order and MUST NOT reorder them: (1) save current snapshot, (2) tear down surfaces, (3) swap `AppModel` workspace/sidebar state, (4) swap `ConfigFile`, (5) reload ghostty config, (6) update `activeProfileID`, (7) persist `profiles.json`.

#### Scenario: Ordering prevents stale callbacks

- **WHEN** a switch is in progress
- **THEN** surface teardown completes before any mutation to `AppModel.workspaces` so that callbacks firing during teardown resolve against consistent state

#### Scenario: Ordering prevents wrong-theme flash

- **WHEN** a switch is in progress
- **THEN** the new `ConfigFile` is in place and `GhosttyApp.reloadConfig` has been called before the first SwiftUI re-render of terminal views, so surfaces instantiate with the target profile's theme from the first frame
