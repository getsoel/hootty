# Pin Workspace Sidebar

## Overview

Sidebar presentation of pinned workspace: sorted to top, visual indicator, and context menu integration.

## Behavior

### Sort Order

- The pinned workspace MUST appear first in the sidebar workspace list, regardless of its position in the `workspaces` array.
- Non-pinned workspaces MUST maintain their existing relative order after the pinned workspace.
- If no workspace is pinned, sidebar order MUST match the `workspaces` array order (no change from current behavior).

### Visual Indicator

- The pinned workspace row MUST display a pin icon (SF Symbol `pin.fill`) to indicate pinned status.
- The pin icon SHOULD be rendered in the muted text color (`tokens.textMuted`) at caption size.
- The pin icon MUST be visually distinct from other status indicators (status dot, layout thumbnail).

### Context Menu

- Each workspace row's context menu MUST include a "Pin Workspace" action when the workspace is not pinned.
- Each workspace row's context menu MUST include a "Unpin Workspace" action when the workspace is pinned.
- Only one workspace MAY be pinned — pinning a different workspace MUST unpin the previously pinned one.

### Drag and Drop

- Drag-and-drop reordering of workspaces SHOULD continue to work for non-pinned workspaces.
- The pinned workspace SHOULD still be draggable (dragging it reorders it in the underlying array, but it remains visually first while pinned).

### Removed Sidebar Elements

- REMOVED: "Docked" pseudo-workspace section — Reason: no docked panel. Migration: pinned workspace is a regular workspace shown first.
- REMOVED: "Toggle Docked Panel" button in sidebar header — Reason: no panel to toggle.
- REMOVED: Persistent pane rows in sidebar — Reason: no persistent panes.
- REMOVED: Drop target for moving panes to docked panel — Reason: no docked panel.
- REMOVED: "Move to Docked" context menu on pane rows — Reason: no docked panel.
- REMOVED: "Move to Workspace" submenu on persistent pane rows — Reason: no persistent panes.

### Sidebar Navigation (SidebarNavigation)

- MODIFIED: `allNavigableItems()` MUST no longer include a persistent pseudo-workspace. The pinned workspace is navigated as a regular workspace (just sorted first).
- MODIFIED: `workspaceForPane()` MUST no longer return `persistentWorkspaceID`. All panes belong to real workspaces.
