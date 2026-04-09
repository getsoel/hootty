## ADDED Requirements

### Requirement: Profiles Metadata File

The system SHALL persist profile metadata to a single `profiles.json` file at the root of the Hootty application support directory. The file MUST contain the ordered list of profiles (each with `id` and `name`) and the `activeProfileID`.

#### Scenario: Write on change

- **WHEN** any mutation to `profiles` or `activeProfileID` occurs (create, rename, delete, switch)
- **THEN** `profiles.json` is atomically rewritten before the operation returns

#### Scenario: Read at launch

- **WHEN** the app launches and `profiles.json` exists and is well-formed
- **THEN** its contents populate `AppModel.profiles` and `AppModel.activeProfileID` before any workspace snapshot is loaded

#### Scenario: Corrupt metadata file

- **WHEN** `profiles.json` exists but fails to decode
- **THEN** the system SHALL log the failure, treat the situation as "no profiles file" for the purposes of migration, and fall back to the migration or first-launch paths

### Requirement: Per-Profile Directory Layout

Each profile SHALL own a dedicated directory at `profiles/<uuid>/` under the Hootty application support directory containing:
- A `config` file (a `ConfigFile` store following the existing format)
- A `workspaces.json` file (a `WorkspaceSnapshot` in the existing format)

The directory name MUST match the profile's `id` verbatim. No profile data SHALL be stored outside its directory.

#### Scenario: Create directory on profile creation

- **WHEN** a profile is created via `AppModel.createProfile`
- **THEN** its `profiles/<uuid>/` directory is created on disk with a `config` file seeded from `ConfigFile.defaultConfigContent()` and no `workspaces.json` yet

#### Scenario: Lazy workspaces file

- **WHEN** a profile has been created but never activated or saved
- **THEN** the absence of `workspaces.json` in its directory is valid, and activating the profile SHALL hit the same empty-state path as a first-ever launch (auto-create one workspace)

#### Scenario: Reads and writes target the active profile

- **WHEN** any code reads or writes `WorkspaceSnapshot` or `ConfigFile` values while a profile is active
- **THEN** the read or write targets files inside that profile's directory and never the root of the application support directory

### Requirement: Per-Profile Store Factories

`ProfileStore` SHALL expose factories that return a `WorkspaceStore` and a `ConfigFile` bound to a specific profile's directory. These factories are the only supported way to obtain per-profile stores at runtime.

#### Scenario: Obtain active profile stores

- **WHEN** switching to or loading a profile
- **THEN** `ProfileStore` returns a `WorkspaceStore(fileURL:)` pointed at the profile's `workspaces.json` and a `ConfigFile(fileURL:)` pointed at the profile's `config` file

#### Scenario: Stores outlive switching

- **WHEN** the active profile changes
- **THEN** the `AppModel` replaces its current `workspaceStore` and `configFile` references with fresh instances from `ProfileStore`, and any previously-held references are no longer used for reads or writes

### Requirement: Migration from Pre-Profiles Layout

On launch, if `profiles.json` does not exist but a root-level `config` and/or `workspaces.json` are present in the Hootty application support directory, the system SHALL perform a one-shot migration that:
1. Generates a new profile `id`.
2. Creates `profiles/<uuid>/`.
3. Moves the existing `config` and `workspaces.json` into the new directory, preserving their contents.
4. Writes `profiles.json` containing a single profile named "Default" with that `id` marked active.

The migration MUST be idempotent and MUST NOT clobber an existing `profiles.json` or an existing target directory.

#### Scenario: Fresh upgrade with existing data

- **WHEN** the app launches, `profiles.json` is absent, and root-level `config` and `workspaces.json` both exist
- **THEN** a `profiles/<new-uuid>/` directory is created, both files are moved inside it, and `profiles.json` is written listing one "Default" profile marked active

#### Scenario: Upgrade with only a config file present

- **WHEN** the app launches, `profiles.json` is absent, only the root `config` exists (no `workspaces.json`), and no legacy data otherwise
- **THEN** migration still runs: it creates the profile directory, moves `config` into it, and writes `profiles.json` with a single "Default" profile

#### Scenario: No-op when already migrated

- **WHEN** the app launches and `profiles.json` already exists
- **THEN** no migration is performed, root-level legacy files (if any) are left untouched, and normal profile loading proceeds

#### Scenario: Partial prior migration recovery

- **WHEN** the app launches and `profiles.json` is absent, but a `profiles/` directory already contains subdirectories from a crashed prior migration attempt
- **THEN** the migration SHALL either complete using the existing partial state or abort without deleting files, and SHALL NOT silently overwrite the partially-created data

### Requirement: DEBUG and Release Path Parity

The profiles layout, migration, and file I/O SHALL operate identically under the DEBUG `Hootty-Dev` application support directory and the release `Hootty` application support directory, with no shared state between them.

#### Scenario: DEBUG build isolation

- **WHEN** a DEBUG build launches
- **THEN** it reads and writes `profiles.json` and `profiles/` under `Hootty-Dev/` and never touches the release `Hootty/` directory
