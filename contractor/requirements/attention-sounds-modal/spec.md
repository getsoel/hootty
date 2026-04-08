# Attention Sounds Modal

## Overview

A modal panel for configuring which macOS system sound plays for each `AttentionKind`. Follows the existing modal overlay pattern (theme picker, command palette).

## Behavior

### Display

- The modal MUST appear as a floating panel centered horizontally, offset from top (consistent with other modals).
- The modal MUST show a scrim backdrop that dismisses on click.
- The modal MUST display one row per `AttentionKind` case, labeled with a human-readable name.
- Each row MUST show the current sound selection (sound name, or "None" if nil).
- The modal MUST use design tokens from `DesignTokens` for all colors, spacing, and typography.

### Sound Selection

- Each row MUST provide a dropdown/picker listing all available system sounds.
- The picker MUST include a "None" option that clears the sound for that attention kind.
- The available sounds MUST come from `SoundManager.availableSystemSounds()`.
- Selecting a sound MUST immediately persist to the config file via `SoundManager`.

### Preview Playback

- Each row SHOULD include a play button to preview the currently selected sound.
- Pressing play MUST invoke `SoundManager.soundPlayer` with the sound name.
- The play button SHOULD be disabled when "None" is selected.

### Dismissal

- The modal MUST dismiss on Escape key press.
- The modal MUST dismiss on scrim tap.

### Layout

- Rows MUST be ordered by `AttentionKind.allCases` order.
- The modal SHOULD have a title header ("Attention Sounds").
- The modal MAY use a fixed width narrower than the theme picker (sounds need less horizontal space).
