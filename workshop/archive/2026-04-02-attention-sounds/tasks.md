# Tasks: Attention Sounds

## 1. Model — AttentionKind extensions

- [x] 1.1 Add `CaseIterable` conformance to `AttentionKind` in `Sources/HoottyCore/Pane.swift`
- [x] 1.2 Add `displayName: String` computed property to `AttentionKind` ("Bell", "Claude Done")

## 2. Model — SoundManager API

- [x] 2.1 Delete `SoundTrigger` enum from `Sources/HoottyCore/SoundManager.swift`
- [x] 2.2 Add `doneSound: String?` computed property reading/writing `hootty-done-sound` via ConfigFile
- [x] 2.3 Change `sound(for:)` to take `AttentionKind` — return `bellSound` for `.bell`, `doneSound` for `.done`
- [x] 2.4 Change `play(_:)` to take `AttentionKind`

## 3. Config — Defaults and migration

- [x] 3.1 Update `ConfigFile.defaultConfigContent()` — replace `attention-idle-sound` and `attention-input-sound` comments with `# hootty-done-sound =`
- [x] 3.2 Update migration in `ConfigFile.migrate()` — map `attention-idle-sound` → `hootty-done-sound`, remove `attention-input-sound` mapping

## 4. Event dispatch

- [x] 4.1 Update `HoottyApp.handleGhosttyEvent(.bellRang)` — call `soundManager.play(.bell)` (verify already correct after API change)
- [x] 4.2 Update `HoottyApp.handleGhosttyEvent(.paneNeedsAttention)` — call `soundManager.play(kind)` instead of `soundManager.play(.bell)`

## 5. Command and modal state

- [x] 5.1 Add `attentionSounds` case to `AppCommand` with title "Attention Sounds..." and no shortcut hint
- [x] 5.2 Add `.attentionSounds` case to `AppModel.ModalState`
- [x] 5.3 Register `attentionSounds` handler in `HoottyApp.registerCommands()` — sets `appModel.modalState = .attentionSounds`

## 6. UI — AttentionSoundsView

- [x] 6.1 Create `Sources/Hootty/Views/AttentionSoundsView.swift` — modal panel with scrim, title header, one row per `AttentionKind.allCases`
- [x] 6.2 Each row: label (`displayName`), sound picker dropdown (system sounds + "None"), play preview button
- [x] 6.3 Sound selection persists immediately via `SoundManager` properties
- [x] 6.4 Dismiss on Escape and scrim tap
- [x] 6.5 Add `.attentionSounds` overlay case in `ContentView.swift`

## 7. Tests

- [x] 7.1 Update `SoundManagerTests` — change all `SoundTrigger` references to `AttentionKind`, add tests for `doneSound` config round-trip
- [x] 7.2 Add test: `play(.done)` calls `soundPlayer` when `doneSound` is set
- [x] 7.3 Add test: `play(.done)` does nothing when `doneSound` is nil
- [x] 7.4 Update any `ConfigFileTests` that reference old `attention-idle-sound` / `attention-input-sound` keys

## 8. Verify

- [x] 8.1 `make build` succeeds
- [x] 8.2 `swift test` passes
- [x] 8.3 `make format-check` passes
- [x] 8.4 `make lint` passes
