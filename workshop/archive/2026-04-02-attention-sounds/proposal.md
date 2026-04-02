# Attention Sounds

## Why

The app has two systems that should be one: `AttentionKind` (visual pane state) and `SoundTrigger` (audio playback). They don't align — `SoundTrigger` only has `.bell`, while `AttentionKind` has `.bell` and `.done`. When Claude finishes thinking, the `.done` attention fires but plays the bell sound (or nothing), with no way to configure a distinct notification.

There's also no UI for configuring sounds. Users must hand-edit the config file and guess at valid system sound names.

## What Changes

- Delete `SoundTrigger` enum — `AttentionKind` becomes the key for sound lookup
- Add `doneSound` config property to `SoundManager` (key: `hootty-done-sound`)
- Fix event dispatch so `.paneNeedsAttention` plays the sound matching its `AttentionKind` instead of always `.bell`
- Add an "Attention Sounds" modal UI for picking a system sound per attention kind
- Add `attentionSounds` command to `AppCommand` (opens the modal from palette/menu)
- Migrate old placeholder config keys (`attention-idle-sound`, `attention-input-sound`) to `hootty-done-sound`

## Capabilities

### New Capabilities
- **attention-sounds-modal** — Modal UI for configuring which system sound plays for each `AttentionKind`, with preview playback
- **attention-sounds-command** — Command palette entry "Attention Sounds..." that opens the modal

### Modified Capabilities
- **sound-playback** — `SoundManager.play()` takes `AttentionKind` instead of `SoundTrigger`; dispatch in event handler passes through the attention kind

## Impact

- **Config file** — New key `hootty-done-sound`. Old placeholder comments replaced. Migration handles renamed keys.
- **Tests** — `SoundManagerTests` updated for new API. Integration test for round-trip config of both sounds.
- No database, network, or dependency changes.
