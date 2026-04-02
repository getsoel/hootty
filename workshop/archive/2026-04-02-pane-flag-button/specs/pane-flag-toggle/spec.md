# Spec: pane-flag-toggle

Toggle a visual flag on/off for panes, providing a lightweight bookmark mechanism.

## Model

- `Pane` MUST expose a boolean `isFlagged` property, defaulting to `false`.
- `Pane` MUST provide a `toggleFlag()` method that flips `isFlagged`.
- The flag state MUST be in-memory only (not persisted via Codable), matching the note property behavior.

## Pane Bar Button

- The pane bar MUST display a flag toggle button for the focused pane.
- The button MUST use `BarIconButton` with the SF Symbol `"flag"` when unflagged and `"flag.fill"` when flagged.
- When the pane is flagged, the button icon MUST use the `statusWarning` design token color (yellow).
- When the pane is unflagged, the button MUST use the default muted icon color (nil iconColor).
- Clicking the button MUST toggle the pane's `isFlagged` state.

## Sidebar Indicator

- When a pane is flagged, `SidebarPaneRow` MUST display a flag icon (`"flag.fill"`) using `statusWarning` color.
- When a pane is flagged, `SidebarPaneRow` MUST apply a yellow-tinted background highlight to the row.
- The yellow background SHOULD use `statusWarning` at reduced opacity to remain readable.
- When a pane is unflagged, no flag icon or highlight MUST appear in the sidebar row.

## Command Integration

- `AppCommand` MUST include a `flagPane` case with the title "Flag Pane".
- The command MUST have a `shortcutHint` for display in the command palette.
- The command MUST be registered in `CommandRegistry` to toggle the focused pane's flag.
- The command MUST appear in the command palette automatically (via existing `paletteCommands` mechanism).
- The command SHOULD be accessible via a keyboard shortcut.

## Keyboard Shortcut

- A keyboard shortcut MUST be assigned for the flag toggle command.
- The shortcut SHOULD NOT conflict with existing shortcuts (note uses `Ctrl+Shift+F`).
- The shortcut MUST be displayed in the command palette via `shortcutHint`.
- The shortcut MAY also be wired to the macOS menu bar.

## Behavior

- Flagging an already-flagged pane MUST unflag it (toggle semantics).
- Flag state MUST be independent of note state — a pane MAY be both flagged and noted simultaneously.
- Flag state MUST survive split operations (the pane object identity is preserved).
- Flag state MUST NOT persist across app restarts (in-memory only).
