# Design: Attention Sounds

## Approach

Unify the sound system around the existing `AttentionKind` enum. Delete `SoundTrigger`, make `SoundManager` key off `AttentionKind`, and add a modal UI following the same pattern as `ThemePickerView`.

The change flows bottom-up: model changes first (AttentionKind conformances, SoundManager API), then event dispatch fix, then UI on top.

## Key Decisions

### Use `AttentionKind` directly instead of a parallel enum

`SoundTrigger` existed as a separate enum from `AttentionKind` — same concepts, different names, incomplete coverage. Rather than keeping two enums in sync, `SoundManager.play()` takes `AttentionKind` directly. If a future attention kind doesn't need sound, its `sound(for:)` case returns `nil`.

### Config key naming: `hootty-done-sound` not `hootty-attention-done-sound`

The `hootty-bell-sound` key is already established. Following the same pattern: `hootty-{kind}-sound` where `{kind}` matches `AttentionKind.rawValue`. Keeps keys short and consistent.

### Standalone modal, not embedded in a settings view

No settings view exists yet. Building a full settings panel is out of scope. The attention sounds modal is self-contained — same pattern as theme picker. Can be moved into a future settings view later.

### No custom sound file support (yet)

`availableSystemSounds()` reads from `/System/Library/Sounds/` only. `NSSound(named:)` also searches `~/Library/Sounds/` at playback time, but we don't enumerate that directory. This keeps the picker simple — 14 system sounds + "None". Custom sounds can be added later by expanding the enumeration.

### `AttentionKind` gets `CaseIterable` and `displayName`

The UI iterates all cases to build rows. `displayName` provides human-readable labels ("Bell", "Claude Done") without the UI needing to know about enum internals. Both additions are in HoottyCore, keeping the view layer thin.

### Immediate persist on selection (no confirm/cancel)

Matches how `ThemePickerView` works — selecting a theme applies it immediately. Sound selection writes to `ConfigFile` on change. No undo needed; the user can just pick a different sound or "None".

## Dependencies

No new dependencies. Uses existing `NSSound`, `ConfigFile`, `DesignTokens`, and the modal overlay system.
