## 1. Core Types

- [x] 1.1 Create `Sources/HoottyCore/Profile.swift` with the `Profile` struct (`id: UUID`, `name: String`), `Codable` and `Equatable` conformance
- [x] 1.2 Add a `ProfilesMetadata` `Codable` struct (`activeProfileID: UUID`, `profiles: [Profile]`) in the same file or a sibling file
- [x] 1.3 Add unit tests in `Tests/HoottyCoreTests/ProfileTests.swift` covering Codable round-trips for `Profile` and `ProfilesMetadata`

## 2. ProfileStore and Persistence

- [x] 2.1 Create `Sources/HoottyCore/ProfileStore.swift` with `init(rootDirectory: URL)` and `init()` (defaults to `Hootty[-Dev]` under app support)
- [x] 2.2 Implement `loadMetadata()` and `saveMetadata(_:)` reading and writing `profiles.json` atomically
- [x] 2.3 Implement `profileDirectory(for: UUID)` that returns `rootDirectory/profiles/<uuid>/`
- [x] 2.4 Implement `workspaceStore(for: UUID) -> WorkspaceStore` returning a `WorkspaceStore(fileURL:)` pointed at the profile's `workspaces.json`
- [x] 2.5 Implement `configFile(for: UUID) -> ConfigFile` returning a `ConfigFile(fileURL:)` pointed at the profile's `config`
- [x] 2.6 Implement `createProfileDirectory(id:seedingDefaultConfig:)` that creates the directory and writes a fresh `config` from `ConfigFile.defaultConfigContent()`
- [x] 2.7 Implement `deleteProfileDirectory(id:)` that recursively removes the profile's directory
- [x] 2.8 Add integration tests in `Tests/HoottyCoreTests/ProfileStoreTests.swift` for metadata round-trips and directory creation using temp directories

## 3. Migration from Legacy Layout

- [x] 3.1 Add `migrateIfNeeded()` to `ProfileStore` that runs before any other profile operation
- [x] 3.2 Implement the happy path: absent `profiles.json` + existing root `config` / `workspaces.json` → generate UUID, create `profiles/<uuid>/`, move both files in, write `profiles.json` atomically with the profile named "Default" marked active
- [x] 3.3 Implement the no-legacy path: absent `profiles.json` and no legacy files → write `profiles.json` with a single "Default" profile and lazy directory creation
- [x] 3.4 Implement the already-migrated idempotent no-op path
- [x] 3.5 Implement the partial-migration recovery path (a `profiles/` directory exists but no `profiles.json`): log and refuse to overwrite
- [x] 3.6 Add integration tests in `Tests/HoottyCoreTests/ProfileMigrationTests.swift` covering each path with temp directory fixtures

## 4. AppModel Profile State

- [x] 4.1 Add `profiles: [Profile]` and `activeProfileID: UUID` observable properties to `AppModel`
- [x] 4.2 Add `activeProfile: Profile?` computed property
- [x] 4.3 Add `profileStore: ProfileStore` stored property and update `AppModel.init` to construct it, run migration, load metadata, and use per-profile `WorkspaceStore` / `ConfigFile` factories
- [x] 4.4 Update the existing `init` parameter list so tests can inject a custom `ProfileStore` with a temp root directory
- [x] 4.5 Update `Tests/HoottyCoreTests/IntegrationTests.swift` existing suites that instantiate `AppModel` to use the new injection point without changing their coverage

## 5. AppModel Profile CRUD

- [ ] 5.1 Implement `createProfile(named:)` that disambiguates duplicate names (same suffix scheme as `nextWorkspaceName()`), calls `ProfileStore.createProfileDirectory`, appends to `profiles`, and persists metadata; does not activate
- [ ] 5.2 Implement `renameProfile(id:to:)` that rejects empty names, updates in-memory state, and persists metadata
- [ ] 5.3 Implement `deleteProfile(id:)` that rejects deletion of the last profile, switches active profile first if deleting the active one, then removes from `profiles`, deletes the directory, and persists metadata
- [ ] 5.4 Add integration tests in `Tests/HoottyCoreTests/ProfileCRUDTests.swift` covering each operation and its guardrails (empty name, last profile, duplicate names, delete-active)

## 6. Profile Switching

- [ ] 6.1 Add `switchProfile(to:)` to `AppModel` with a same-id no-op short-circuit and an unknown-id rejection
- [ ] 6.2 In the switch implementation, step 1: flush any pending debounced save and call `saveWorkspaces()` on the current profile's `WorkspaceStore`
- [ ] 6.3 Step 2: tear down surfaces by iterating `workspaces` and calling `GhosttyApp.cleanupWorkspace(_:)` (this requires passing a teardown closure into `AppModel` or exposing a hook — choose whichever keeps `HoottyCore` UI-free)
- [ ] 6.4 Step 3: mutate `workspaces`, `selectedWorkspaceID`, `collapsedWorkspaceIDs`, `pinnedWorkspaceID`, `activeSidebarFilters` with the target profile's loaded snapshot (or empty-state defaults if no snapshot)
- [ ] 6.5 Step 4: swap `workspaceStore` and `configFile` to the target profile's instances from `ProfileStore`
- [ ] 6.6 Step 5: invoke a caller-provided ghostty reload closure (same injection strategy as 6.3) that calls `GhosttyApp.shared.reloadConfig(ghosttyContent:)`
- [ ] 6.7 Step 6: update `activeProfileID`
- [ ] 6.8 Step 7: persist `profiles.json`
- [ ] 6.9 Add a post-condition assertion/log verifying `GhosttyApp.surfaceViews.isEmpty` and `focusedSurface == nil` after teardown
- [ ] 6.10 Add integration tests in `Tests/HoottyCoreTests/ProfileSwitchTests.swift` that exercise save → swap → hydrate round-trips across two profiles using a mock teardown/reload closure

## 7. AppKit Prompt Helper

- [ ] 7.1 Create `Sources/Hootty/NSAlertPrompt.swift` with a `promptForName(title:prompt:initialValue:) -> String?` helper that shows an `NSAlert` with an accessory `NSTextField` and returns the trimmed input or `nil` on cancel
- [ ] 7.2 Add a `confirmDestructive(title:message:confirmButtonTitle:) -> Bool` helper for delete confirmation (warning style, default button Cancel)

## 8. Commands Layer

- [ ] 8.1 Add `newProfile`, `renameCurrentProfile`, `deleteCurrentProfile` cases to `AppCommand` enum in `Sources/HoottyCore/AppCommand.swift` with titles and optional shortcut hints
- [ ] 8.2 Register handlers in `HoottyApp.registerCommands()` that call the `NSAlertPrompt` helpers and then `AppModel.createProfile` / `renameProfile` / `deleteProfile`
- [ ] 8.3 Extend `CommandRegistry.setSupplementaryCommands` usage in the profile switch path so the palette has one "Switch to Profile: &lt;name&gt;" entry per non-active profile, refreshed on create/rename/delete/switch

## 9. Profile Menu

- [ ] 9.1 Add a `CommandMenu("Profile")` block to `HoottyApp.body` `.commands`, positioned after the View menu
- [ ] 9.2 Inside the menu, add a `Picker("Active", selection: $appModel.activeProfileID)` with `.pickerStyle(.inline)` and a `ForEach(appModel.profiles)` tagging each with its UUID; the picker's binding drives `switchProfile(to:)` via a computed-binding wrapper that calls the switch method
- [ ] 9.3 Add `Divider()` and `Button`s for `New Profile…`, `Rename Current Profile…`, `Delete Current Profile…` that dispatch through `commandRegistry.execute`
- [ ] 9.4 Disable the Delete button when `appModel.profiles.count == 1`
- [ ] 9.5 Manual verification: open the menu, verify the active profile has a checkmark, create/rename/delete work, delete is disabled for the last profile, and the menu updates after each operation

## 10. Titlebar Profile Name

- [ ] 10.1 In `Sources/Hootty/Views/ContentView.swift` `titleBar` computed view, insert a `Text(appModel.activeProfile?.name ?? "")` immediately after the 78pt traffic-light `Color.clear` spacer, before the `Spacer()`
- [ ] 10.2 Use `TypeScale.bodySize` and a token-derived color (`tokens.text` or `tokens.textMuted` — pick whichever reads cleanest against the titlebar background); do not hardcode font size or color
- [ ] 10.3 Manual verification: launch, verify the active profile name appears to the right of the traffic lights and updates on switch and rename, memory monitor remains visible, titlebar height unchanged

## 11. End-to-End Integration

- [ ] 11.1 Manual test: fresh install — launch, verify migration creates "Default" profile, verify titlebar shows "Default", verify Profile menu lists "Default" with checkmark
- [ ] 11.2 Manual test: create "Work" profile via menu, verify it appears with empty-state workspace, verify titlebar updates, verify theme changes if the default config differs
- [ ] 11.3 Manual test: switch back to "Default", verify previous workspaces restored, verify theme restored
- [ ] 11.4 Manual test: rename active profile, verify menu and titlebar update
- [ ] 11.5 Manual test: delete non-active profile, verify it disappears from menu and its directory is removed from disk
- [ ] 11.6 Manual test: delete active profile with two profiles present, verify active switches before deletion completes
- [ ] 11.7 Manual test: attempt to delete the last profile, verify the menu item is disabled
- [ ] 11.8 Manual test: migration re-run idempotency — relaunch after migration has already happened, verify no files are touched
- [ ] 11.9 Manual test: command palette — open palette, verify "Switch to Profile: &lt;name&gt;" entries for non-active profiles only, select one and verify it switches

## 12. Verification and Cleanup

- [ ] 12.1 Run `make build` and resolve any compilation issues
- [ ] 12.2 Run `swift test` and verify all Swift Testing suites pass (ignoring signal 10 from the XCTest runner per CLAUDE.local.md)
- [ ] 12.3 Run `make format-check` and address any formatting issues via `make format`
- [ ] 12.4 Run `make lint` and address any SwiftLint findings
- [ ] 12.5 Verify only task-relevant files changed by reviewing `git status` / `git diff`
