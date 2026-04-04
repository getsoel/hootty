# Persistent Panel Model

## Overview

`AppModel` properties for the persistent panel's split node tree, visibility, and width. Serialized alongside workspaces via `WorkspaceStore`.

## Model Properties

- ADDED: `AppModel.persistentNode: SplitNode?` — the panel's split tree root, `nil` when no persistent panes exist.
- ADDED: `AppModel.persistentPanelVisible: Bool` — whether the panel is shown, defaulting to `false`.
- ADDED: `AppModel.persistentPanelWidth: CGFloat` — panel width in points, defaulting to 400.
- ADDED: `AppModel.persistentPanelMinWidth: CGFloat` — static constant, 200.
- ADDED: `AppModel.persistentPanelMaxWidth: CGFloat` — static constant, 600.
- ADDED: `AppModel.persistentFocusedPaneID: UUID?` — the focused pane within the persistent panel.

## Panel Lifecycle

- When `persistentNode` is `nil` and the user opens the panel, a new `SplitNode` with a single default `Pane` MUST be created.
- When the last pane is removed from the persistent panel, `persistentNode` MUST be set to `nil` and `persistentPanelVisible` MUST be set to `false`.
- Setting `persistentPanelVisible = true` when `persistentNode` is `nil` MUST create a default pane automatically.

## Pane Lookup

- MODIFIED: `AppModel.findPane(id:)` MUST search `persistentNode` in addition to workspace root nodes.
- When a pane is found in the persistent node, the method MUST return a distinguishable result. The return type SHOULD be extended or a separate method SHOULD be added (e.g., `findPaneLocation(id:)` returning an enum of `.workspace(Workspace, Pane)` | `.persistent(Pane)`).
- MODIFIED: `AppModel.withPane(id:)` MUST also search the persistent node.

## Focused Pane

- `persistentFocusedPaneID` MUST track the focused pane within the persistent panel independently from workspace focus.
- When the persistent panel has application focus, `persistentFocusedPaneID` MUST be set; workspace `focusedPaneID` MAY remain unchanged (preserving last-focused state per workspace).
- `AppModel` MUST expose a computed `persistentFocusedPane: Pane?` that resolves the ID against `persistentNode`, falling back to the first pane.

## Attention Aggregation

- MODIFIED: Global `AttentionCounts` aggregation (used by sidebar badge pills) MUST include panes from `persistentNode`.
- The persistent panel's panes MUST participate in thinking/flagged/done/bell counts alongside workspace panes.

## Persistence

- MODIFIED: `WorkspaceSnapshot` MUST add an optional `persistentNode: SplitNode?` field.
- MODIFIED: `WorkspaceSnapshot` MUST add an optional `persistentPanelVisible: Bool?` field.
- MODIFIED: `WorkspaceSnapshot` MUST add an optional `persistentPanelWidth: CGFloat?` field.
- On decode, if these fields are absent or nil, the panel MUST default to hidden with no node (backward-compatible).
- `AppModel.saveWorkspaces()` MUST include persistent panel state in the snapshot.
- `AppModel.debouncedSave()` MUST be triggered when persistent panel properties change (pane events, width resize, visibility toggle).

## Reset

- MODIFIED: `AppModel.resetWorkspaces()` MUST also clear `persistentNode`, set `persistentPanelVisible` to `false`, and reset `persistentPanelWidth` to the default.
