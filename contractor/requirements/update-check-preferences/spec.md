## ADDED Requirements

### Requirement: Opt-out preference
The app SHALL expose a user-facing boolean preference "Check for updates on launch" that defaults to enabled, and SHALL persist the value across launches in `UserDefaults`.

#### Scenario: Default on first launch
- **WHEN** the app launches for the first time with no stored preference
- **THEN** the preference resolves to enabled
- **AND** the update check runs normally

#### Scenario: Preference toggled off
- **WHEN** the user disables the preference
- **THEN** the value is persisted to `UserDefaults`
- **AND** on the next launch the service MUST NOT issue any network request
- **AND** no update indicator is shown at any time while the preference is disabled

#### Scenario: Preference toggled back on
- **WHEN** the user re-enables the preference after previously disabling it
- **THEN** the value is persisted
- **AND** on the next eligible launch the service resumes checks using the standard throttle rules

### Requirement: Preference surface
The preference SHALL be reachable from a location consistent with existing Hootty preference surfaces (design-phase decision) and MUST be labelled clearly enough that users can locate it without reading docs.

#### Scenario: Preference discoverable in UI
- **WHEN** a user navigates to the chosen preferences surface
- **THEN** the toggle is present with a label matching "Check for updates on launch" (or equivalent wording agreed in design)

#### Scenario: No hidden defaults
- **WHEN** the preference is disabled
- **THEN** the app MUST NOT issue update-related network requests through any other code path
