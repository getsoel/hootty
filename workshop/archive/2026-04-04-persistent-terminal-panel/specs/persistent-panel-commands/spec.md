# Persistent Panel Commands

## Overview

Commands for toggling the persistent panel, focusing it, splitting within it, and moving panes to/from it.

## New Commands

### Toggle Persistent Panel

- ADDED: `AppCommand.togglePersistentPanel` with title "Toggle Persistent Panel".
- The command `shortcutHint` MUST be `"⌘⌥P"`.
- The handler MUST toggle `appModel.persistentPanelVisible`.
- When toggling visible and `persistentNode` is `nil`, the handler MUST create a default pane.
- The command MUST be registered in `HoottyApp.registerCommands()`.
- The command MUST appear in the command palette.
- A `.keyboardShortcut("p", modifiers: [.command, .option])` MUST be added to the menu bar.

### Focus Persistent Panel

- ADDED: `AppCommand.focusPersistentPanel` with title "Focus Persistent Panel".
- The command `shortcutHint` MUST be `"⌘\\"`.
- The handler MUST:
  1. If focus is currently in a workspace pane, move focus to the persistent panel's focused pane.
  2. If focus is currently in the persistent panel, move focus back to the selected workspace's focused pane.
- If the persistent panel is not visible, the command MUST make it visible first.
- The command MUST set `appModel.sidebarHasFocus = false`.

### Move Pane to Persistent Panel

- ADDED: `AppCommand.movePaneToPersistentPanel` with title "Move Pane to Pinned".
- The command MAY have no `shortcutHint`.
- The handler MUST move the currently focused workspace pane into the persistent panel.
- If the persistent panel has no node, the moved pane MUST become its root.
- If the persistent panel already has panes, the moved pane MUST be appended as a vertical split.
- The command MUST be a no-op if the focused pane is already in the persistent panel.
- After moving, the persistent panel MUST become visible.

### Move Pane to Workspace

- ADDED: `AppCommand.movePaneToWorkspace` with title "Move Pane to Workspace".
- The command MAY have no `shortcutHint`.
- The handler MUST move the currently focused persistent panel pane into the selected workspace.
- The pane MUST be appended to the workspace's split tree as a new split.
- The command MUST be a no-op if the focused pane is already in a workspace.

### Split Persistent Pane

- Splitting within the persistent panel MUST reuse the existing `splitDown` command behavior.
- When focus is in the persistent panel and a split command is executed, the split MUST operate on the persistent node tree, not any workspace.
- The command registry MUST detect whether focus is in the persistent panel or a workspace and dispatch to the correct node.

## Menu Bar

- A "Persistent Panel" submenu SHOULD be added under the View menu.
- The submenu MUST include "Toggle Persistent Panel" with its keyboard shortcut.
- The submenu MUST include "Focus Persistent Panel" with its keyboard shortcut.
- The submenu MAY include "Move Pane to Pinned" and "Move Pane to Workspace".

## Ghostty Action Integration

- Split actions dispatched from a ghostty surface in the persistent panel MUST route to the persistent node tree.
- The `GhosttyApp.handleAction` callback MUST determine whether the originating surface belongs to a workspace pane or a persistent pane and dispatch accordingly.
