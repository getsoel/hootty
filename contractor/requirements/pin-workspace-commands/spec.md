# Pin Workspace Commands

## Overview

Two commands replace the 8 docked panel commands: one to toggle pin state, one to focus the pinned workspace.

## Behavior

### Command Definitions

- `pinWorkspace` command MUST exist with title "Pin/Unpin Workspace".
- `pinWorkspace` SHOULD have no default keyboard shortcut (invoked via command palette or context menu).
- `focusPinnedWorkspace` command MUST exist with title "Focus Pinned Workspace".
- `focusPinnedWorkspace` MUST have keyboard shortcut hint "Cmd+\\".

### Pin/Unpin Behavior

- Executing `pinWorkspace` MUST call `appModel.togglePinWorkspace(id:)` with the currently selected workspace ID.
- If no workspace is selected, the command MUST be a no-op.

### Focus Pinned Behavior

- Executing `focusPinnedWorkspace` MUST set `selectedWorkspaceID` to `pinnedWorkspaceID`.
- If `pinnedWorkspaceID` is `nil`, the command MUST be a no-op.
- If the pinned workspace is already selected, the command SHOULD be a no-op (no visual flicker).

### Menu Integration

- `focusPinnedWorkspace` SHOULD appear in the Window menu with its keyboard shortcut.
- Both commands MUST appear in the command palette.

### Removed Commands

- REMOVED: `toggleDockedPanel` (Cmd+Opt+P) — Reason: no docked panel.
- REMOVED: `focusDockedPanel` (Cmd+\\) — Reason: replaced by `focusPinnedWorkspace`.
- REMOVED: `movePaneToDockedPanel` — Reason: no docked panel.
- REMOVED: `movePaneToWorkspace` — Reason: no pane movement between domains.
- REMOVED: `movePanelLeft` — Reason: no panel positioning.
- REMOVED: `movePanelRight` — Reason: no panel positioning.
- REMOVED: `movePanelTop` — Reason: no panel positioning.
- REMOVED: `movePanelBottom` — Reason: no panel positioning.

### Modified Command Handlers

- MODIFIED: `focusNextPane` / `focusPreviousPane` MUST only cycle within the selected workspace (no persistent domain branching).
- MODIFIED: `focusPaneUp/Down/Left/Right` MUST only navigate within the selected workspace (no cross-domain logic).
