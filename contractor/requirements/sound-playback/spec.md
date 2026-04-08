# Sound Playback

## Overview

Unify sound triggers with attention kinds so each attention type has its own configurable sound.

## Behavior

### API Changes

- REMOVED: `SoundTrigger` enum. Reason: Redundant with `AttentionKind`. Migration: All call sites use `AttentionKind` directly.
- MODIFIED: `SoundManager.play(_:)` — FROM: `play(_ trigger: SoundTrigger)` → TO: `play(_ kind: AttentionKind)`.
- MODIFIED: `SoundManager.sound(for:)` — FROM: `sound(for trigger: SoundTrigger)` → TO: `sound(for kind: AttentionKind)`.

### Config Properties

- `bellSound` MUST read/write `hootty-bell-sound` (unchanged).
- ADDED: `doneSound` MUST read/write `hootty-done-sound`.
- `sound(for:)` MUST return `bellSound` for `.bell` and `doneSound` for `.done`.

### Event Dispatch

- MODIFIED: `handleGhosttyEvent(.bellRang)` MUST call `soundManager.play(.bell)` (unchanged behavior).
- MODIFIED: `handleGhosttyEvent(.paneNeedsAttention(_, kind))` MUST call `soundManager.play(kind)` instead of `soundManager.play(.bell)`.

### Config File

- MODIFIED: `defaultConfigContent()` MUST replace `# hootty-attention-idle-sound =` and `# hootty-attention-input-sound =` with `# hootty-done-sound =`.
- Migration MUST map `attention-idle-sound` to `hootty-done-sound` for existing configs.
- Migration SHOULD ignore `attention-input-sound` (no equivalent; was never a real setting).

### AttentionKind

- `AttentionKind` MUST conform to `CaseIterable` (needed for UI iteration).
- `AttentionKind` MUST provide a `displayName: String` property returning human-readable labels ("Bell", "Claude Done").
