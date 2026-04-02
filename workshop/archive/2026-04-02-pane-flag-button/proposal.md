# Proposal: Pane Flag Button

## Why

When working with many terminal panes, users need a quick way to visually mark important panes for easy identification. Currently, panes can have text notes, but there's no lightweight "bookmark" mechanism to highlight a pane at a glance. A flag provides a fast, toggle-based visual marker without requiring text input.

## What Changes

- Add a `isFlagged` boolean property to `Pane`
- Add a flag toggle button to the pane bar (PaneGroupTabBar) using `BarIconButton`
- Show a flag icon and yellow background highlight on flagged panes in the sidebar (`SidebarPaneRow`)
- Add a `flagPane` case to `AppCommand` with a keyboard shortcut
- Register the flag command in `CommandRegistry` so it appears in the command palette
- Clicking the flag button or invoking the command toggles the flag on/off

## Capabilities

### New Capabilities

- **pane-flag-toggle**: Toggle a flag on/off for the focused pane via button, keyboard shortcut, or command palette. Flagged panes show a flag icon with yellow highlight in both the pane bar and sidebar.

### Modified Capabilities

- (none)

## Impact

- **Model**: New `isFlagged` property on `Pane` (in-memory only, not persisted — matches note behavior)
- **UI**: Minor additions to `PaneGroupTabBar` and `SidebarPaneRow`
- **Commands**: One new `AppCommand` case + registration
- **Dependencies**: None — uses existing `BarIconButton`, `DesignTokens`, and command patterns
