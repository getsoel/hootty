## ADDED Requirements

### Requirement: Top-Level Profile Menu

Hootty SHALL install a top-level `Profile` menu in the macOS menu bar. The menu SHALL contain, in order:
1. A dynamic, inline-rendered list of all profiles, with the active profile marked.
2. A separator.
3. `New Profile…`
4. `Rename Current Profile…`
5. `Delete Current Profile…`

#### Scenario: Menu is present at launch

- **WHEN** the app launches with any number of profiles
- **THEN** the `Profile` menu appears in the macOS menu bar with at least one profile entry and the three static commands

#### Scenario: Active profile is marked

- **WHEN** the menu is opened
- **THEN** the currently active profile is visually marked (e.g., a checkmark via `Picker.inline` selection) and all other profiles are unmarked

### Requirement: Dynamic Profile List

The dynamic list SHALL reflect `AppModel.profiles` in its stored order and MUST re-render whenever profiles are created, renamed, deleted, or switched.

#### Scenario: Added profile appears in menu

- **WHEN** a new profile is created
- **THEN** on the next menu open, the new profile appears in the dynamic list with its assigned name

#### Scenario: Renamed profile updates label

- **WHEN** the active profile is renamed
- **THEN** on the next menu open, the corresponding entry displays the new name

#### Scenario: Deleted profile is removed

- **WHEN** a profile is deleted
- **THEN** on the next menu open, its entry is no longer in the dynamic list

### Requirement: Switch via Menu

Selecting a profile entry from the dynamic list SHALL invoke `AppModel.switchProfile(to:)` with that profile's id. Selecting the already-active profile entry SHALL be a no-op.

#### Scenario: Click non-active profile

- **WHEN** the user selects a profile that is not currently active
- **THEN** `switchProfile(to:)` is invoked with that profile's id and the switch completes

#### Scenario: Click active profile

- **WHEN** the user selects the currently active profile's entry
- **THEN** no switch is performed and no state changes

### Requirement: New Profile Command

The `New Profile…` command SHALL present a standard AppKit `NSAlert` with an accessory text field for entering a name. On confirm, the system SHALL call `AppModel.createProfile(named:)` and then `switchProfile(to:)` to activate the new profile.

#### Scenario: Confirm with a valid name

- **WHEN** the user enters "Work" in the prompt and confirms
- **THEN** a profile named "Work" is created and the app switches to it, showing its empty-state workspace

#### Scenario: Confirm with an empty name

- **WHEN** the user confirms the prompt with an empty or whitespace-only name
- **THEN** no profile is created and the app state is unchanged

#### Scenario: Cancel prompt

- **WHEN** the user dismisses the prompt without confirming
- **THEN** no profile is created and the app state is unchanged

### Requirement: Rename Current Profile Command

The `Rename Current Profile…` command SHALL present an `NSAlert` with an accessory text field pre-filled with the active profile's current name. On confirm, the system SHALL call `AppModel.renameProfile(id:to:)` against the active profile.

#### Scenario: Rename to a new name

- **WHEN** the user edits the name and confirms
- **THEN** the active profile is renamed and the menu, titlebar, and command palette observers update to reflect the new name

#### Scenario: Confirm unchanged name

- **WHEN** the user confirms without changing the pre-filled name
- **THEN** no rename occurs and no side effects are produced

### Requirement: Delete Current Profile Command

The `Delete Current Profile…` command SHALL present an `NSAlert` confirmation dialog (warning style) naming the profile to be deleted. On confirm, the system SHALL call `AppModel.deleteProfile(id:)` against the active profile. The menu item SHALL be disabled when `AppModel.profiles.count == 1`.

#### Scenario: Confirm deletion with multiple profiles

- **WHEN** there are multiple profiles and the user confirms deletion of the active one
- **THEN** the app switches to another profile and the formerly-active profile is removed from memory and disk

#### Scenario: Cancel deletion

- **WHEN** the user dismisses the confirmation without confirming
- **THEN** no deletion occurs and the app state is unchanged

#### Scenario: Disabled for sole profile

- **WHEN** only one profile exists
- **THEN** the `Delete Current Profile…` menu item is disabled and cannot be invoked

### Requirement: Command Palette Integration

The command palette SHALL include a dynamic "Switch to Profile: &lt;name&gt;" entry for every non-active profile, supplied via `CommandRegistry.setSupplementaryCommands`. The static commands for new/rename/delete profile SHALL also appear as `AppCommand` cases registered with the command registry.

#### Scenario: Palette lists inactive profiles

- **WHEN** the user opens the command palette
- **THEN** the palette shows one "Switch to Profile: &lt;name&gt;" entry for each profile except the currently active one

#### Scenario: Palette entry triggers switch

- **WHEN** the user selects a "Switch to Profile: &lt;name&gt;" palette entry
- **THEN** `AppModel.switchProfile(to:)` is invoked with that profile's id

#### Scenario: Palette entries update after mutations

- **WHEN** profiles are created, renamed, deleted, or the active profile changes
- **THEN** the palette's supplementary commands are refreshed so the list reflects the current profile state the next time the palette is opened

### Requirement: Menu Placement
The Profile menu SHALL be rendered as a dedicated top-level `CommandMenu("Profile")` in the SwiftUI `.commands` block, placed after the `Workspace` menu in natural order. In the final menu bar ordering, Profile appears between `Workspace` and the system-provided `Window` menu.

#### Scenario: Profile menu placed after Workspace
- **WHEN** the app launches
- **THEN** the menu bar shows `Workspace` immediately before `Profile`, and `Profile` immediately before the system `Window` menu


The Profile menu SHALL be rendered as a dedicated top-level `CommandMenu("Profile")` in the SwiftUI `.commands` block, placed after the `View` menu in natural order.
