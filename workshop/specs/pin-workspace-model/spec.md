# Pin Workspace Model

## Overview

Data model for pinning a single workspace to the top of the sidebar. Replaces the entire persistent/docked panel system with a single optional ID.

## Behavior

### Pin State

- AppModel MUST have a `pinnedWorkspaceID: UUID?` property, initially `nil`.
- At most one workspace MAY be pinned at a time.
- Setting `pinnedWorkspaceID` to a workspace ID MUST pin that workspace.
- Setting `pinnedWorkspaceID` to `nil` MUST unpin any workspace.

### Pin/Unpin Operations

- `togglePinWorkspace(id:)` MUST pin the workspace if it is not currently pinned.
- `togglePinWorkspace(id:)` MUST unpin if the given workspace is already pinned.
- If a pinned workspace is deleted (removed from the `workspaces` array), `pinnedWorkspaceID` MUST be set to `nil`.

### Persistence

- `pinnedWorkspaceID` MUST be persisted in `WorkspaceSnapshot`.
- The field MUST be optional in the snapshot — old snapshots without it MUST load with `pinnedWorkspaceID = nil`.
- The field SHOULD NOT be written to the snapshot when `nil` (minimize JSON noise).

### Removed State

- REMOVED: `persistentNode: SplitNode?` — Reason: docked panel replaced by pinning. Migration: field ignored on load.
- REMOVED: `persistentPanelVisible: Bool` — Reason: no panel. Migration: field ignored on load.
- REMOVED: `persistentPanelWidth: CGFloat` — Reason: no panel. Migration: field ignored on load.
- REMOVED: `persistentPanelHeight: CGFloat` — Reason: no panel. Migration: field ignored on load.
- REMOVED: `persistentPanelPosition: PanelPosition` — Reason: no panel. Migration: field ignored on load.
- REMOVED: `persistentFocusedPaneID: UUID?` — Reason: no panel. Migration: field ignored on load.
- REMOVED: `persistentSidebarCollapsed: Bool` — Reason: no panel. Migration: field ignored on load.
- REMOVED: `focusDomain: FocusDomain` — Reason: only one domain remains. Migration: all focus is workspace domain.
- REMOVED: `PanelPosition` enum (file `PanelPosition.swift`) — Reason: no panel positioning needed.
- REMOVED: `FocusDomain` enum (file `FocusDomain.swift`) — Reason: single focus domain.
- REMOVED: `persistentWorkspaceID` static constant — Reason: no pseudo-workspace needed.
- REMOVED: All persistent panel methods (`togglePersistentPanel`, `closePersistentPanel`, `removePersistentPane`, `splitPersistentPane`, `addPersistentPane`, `cyclePersistentFocus`, `movePaneToPersistentPanel`, `movePaneToWorkspace`, `setPanelPosition`) — Reason: replaced by simple pin toggle.
- REMOVED: All persistent panel size constants (`defaultPanelWidth`, `defaultPanelHeight`, etc.) — Reason: no panel.
