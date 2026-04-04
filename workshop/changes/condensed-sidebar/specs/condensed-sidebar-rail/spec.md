# Condensed Sidebar Rail

## Overview

A narrow (~48pt) icon-only sidebar rail that displays workspace, repo, and pane status icons without text. Provides at-a-glance status and quick navigation while consuming minimal horizontal space.

## Behavior

### Layout

- The rail MUST have a fixed width defined by `Layout.condensedSidebarWidth`.
- The rail MUST NOT be resizable (no drag handle).
- The rail background MUST use `tokens.surfaceLow`.
- A 1px border (`tokens.border`) MUST separate the rail from the detail area.

### Expand Button

- The rail MUST display an expand button as the first row at the top.
- The expand button MUST use the `sidebar.left` SF Symbol.
- Clicking the expand button MUST switch the sidebar to `.full` mode.
- The expand button row MUST have height `Layout.barHeight` and background `tokens.tabBarBackground`.
- A 1px border (`tokens.border`) MUST appear below the expand button row.

### Pinned Section

- If a persistent panel exists (`persistentNode != nil`), the rail MUST show a pinned section below the expand button.
- The pinned section header MUST display a `pin.fill` icon.
- Clicking the pinned header icon MUST toggle `persistentSidebarCollapsed`.
- When expanded, each pinned pane MUST appear as a status icon row below the header.
- A 1px divider (`tokens.border`) MUST separate the pinned section from workspace sections.

### Workspace Rows

- Each workspace MUST appear as a folder icon row.
- The icon MUST be `folder.fill` when the workspace is selected, `folder` otherwise.
- The icon color MUST be `tokens.text` when selected, `tokens.textMuted` otherwise.
- Clicking a workspace folder icon MUST toggle collapse/expand for that workspace (using existing `collapsedWorkspaceIDs`).
- The selected workspace MUST have a background fill of `tokens.elementHover`.
- When a workspace is collapsed, if any pane has attention, a `StatusDotView`-style summary indicator MUST overlay or appear adjacent to the folder icon.
- The summary indicator MUST use the existing `WorkspaceAttentionSummary` priority: thinking > done > bell.

### Repo/Branch Section Rows

- When a workspace is expanded and has branch sections, each section MUST appear as an icon row.
- HEAD branches MUST use `cube.fill`, other branches MUST use `cube`.
- Icon color MUST follow the same selected/muted pattern as workspace rows.

### Pane Rows

- Each visible pane MUST appear as a status icon row when its parent workspace is expanded.
- The icon MUST match `StatusDotView` exactly:
  - Done attention: `checkmark.circle` in `tokens.statusDone`
  - Bell attention: `bell` in `tokens.statusBell`
  - Thinking: `arrow.2.circlepath` in `tokens.statusThinking` (animated rotation)
  - Claude session: `bubble.left.fill` in `tokens.textMuted`
  - Default terminal: `apple.terminal` in `tokens.textMuted`
- The focused pane in the selected workspace MUST use `tokens.text` for its icon color.
- The focused pane row MUST have `tokens.elementSelected` background.
- Clicking a pane icon MUST select and focus that pane.
- Pane rows with attention SHOULD have a subtle background tint matching the attention color (same as full sidebar).

### Tooltips

- Every row MUST display a tooltip on hover via `.help()`.
- Workspace rows: workspace name.
- Repo/branch rows: branch display label (e.g., "repo/branch").
- Pane rows: `pane.displayName`.
- Expand button: "Expand sidebar".

### Context Menus

- Right-clicking a workspace icon MUST show the same context menu as the full sidebar (Rename, Collapse/Expand, Close).
- Right-clicking a pane icon MUST show the same context menu as the full sidebar (Rename, Move to Pinned, Close).
- Right-clicking the rail background (not on any row) MUST show a context menu with "New Workspace" and (if persistent panel exists) "New Pinned Pane".

### Hover States

- Rows MUST show `tokens.elementHover` background on hover.
- Rows MUST set the pointing-hand cursor on hover.

### Constraints

- The rail MUST NOT support drag-and-drop.
- The rail MUST NOT display a "+" button.
- The rail MUST NOT display attention badge pills (status is visible per-pane).
- The rail MUST NOT display layout thumbnails.
- The sidebar filter state (`activeSidebarFilters`) MUST still apply to pane visibility in condensed mode.
