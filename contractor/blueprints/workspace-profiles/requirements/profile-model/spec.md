## ADDED Requirements

### Requirement: Profile Value Type

The system SHALL represent a profile as a value type with a stable `UUID` identifier and a human-readable display name. Profiles SHALL be `Codable` and `Equatable`.

#### Scenario: Profile has stable identity

- **WHEN** a profile is created and later loaded from disk
- **THEN** its `id` remains unchanged across the round-trip and uniquely identifies the profile within the list

#### Scenario: Profile name is displayable

- **WHEN** the system renders a profile in the menu or titlebar
- **THEN** it uses the profile's `name` verbatim without transformation

### Requirement: Profile List and Active Profile State

`AppModel` SHALL hold an observable `profiles` list and an observable `activeProfileID`. The list MUST always contain at least one profile, and `activeProfileID` MUST always reference an existing profile in the list.

#### Scenario: Launch with an existing profiles file

- **WHEN** the app launches and `profiles.json` contains one or more profiles with a valid active id
- **THEN** `AppModel.profiles` reflects the file contents and `AppModel.activeProfileID` matches the stored active id

#### Scenario: Launch with no profiles file and no legacy data

- **WHEN** the app launches and neither `profiles.json` nor legacy root files exist
- **THEN** `AppModel` SHALL create exactly one profile named "Default", mark it active, and emit observable updates for `profiles` and `activeProfileID`

#### Scenario: Active profile invariant after deletion

- **WHEN** the currently active profile is deleted and other profiles remain
- **THEN** `activeProfileID` SHALL switch to another profile in the list before the deleted profile is removed from memory

### Requirement: Create Profile

The system SHALL provide a `createProfile(named:)` operation on `AppModel` that appends a new profile to `profiles`, assigns it a fresh `UUID`, and returns the created profile. The new profile MUST NOT become active as a side effect of creation; activation SHALL be a separate explicit step by the caller.

#### Scenario: Create with a unique name

- **WHEN** `createProfile(named: "Work")` is called and no existing profile has that name
- **THEN** a new profile with that name is appended to `profiles`, `profiles.json` is updated, and the active profile does not change

#### Scenario: Create with a duplicate name

- **WHEN** `createProfile(named: "Work")` is called and a profile named "Work" already exists
- **THEN** the new profile is appended with a disambiguated name (e.g. "Work 2") following the same numeric-suffix convention used by `AppModel.nextWorkspaceName()`

#### Scenario: Newly created profile has default config

- **WHEN** a new profile is created
- **THEN** its on-disk `config` file is initialized from `ConfigFile.defaultConfigContent()` so that first activation yields the default theme, font, and sound settings

### Requirement: Rename Profile

The system SHALL provide a `renameProfile(id:to:)` operation on `AppModel` that updates the display name of a profile without changing its `id` or on-disk directory.

#### Scenario: Rename active profile

- **WHEN** `renameProfile` is called on the active profile with a non-empty new name
- **THEN** the profile's `name` is updated, `profiles.json` is rewritten, and observers (menu, titlebar, palette) re-render with the new name

#### Scenario: Rename to empty string

- **WHEN** `renameProfile` is called with an empty or whitespace-only name
- **THEN** the operation is a no-op and the profile retains its previous name

### Requirement: Delete Profile

The system SHALL provide a `deleteProfile(id:)` operation on `AppModel` that removes a profile from `profiles` and removes its on-disk directory. Deletion of the last remaining profile MUST be rejected.

#### Scenario: Delete a non-active profile

- **WHEN** `deleteProfile` is called for a profile that is not currently active and is not the last profile
- **THEN** the profile is removed from `profiles`, its directory under `profiles/` is deleted, `profiles.json` is rewritten, and the active profile does not change

#### Scenario: Delete the active profile

- **WHEN** `deleteProfile` is called for the currently active profile and other profiles remain
- **THEN** the system SHALL switch the active profile to another profile in the list (preferring the first remaining profile in stored order) and then remove the deleted profile and its directory

#### Scenario: Delete the last profile

- **WHEN** `deleteProfile` is called and it would leave `profiles` empty
- **THEN** the operation is rejected with no state change and the profile remains intact on disk
