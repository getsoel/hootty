# Persistent Panel Focus

## Overview

Focus behavior across the workspace/persistent panel boundary. Directional focus crosses the boundary spatially; sequential cycling stays within the current domain.

## Focus Domains

- The application MUST have two focus domains: the **workspace domain** (selected workspace's split tree) and the **persistent domain** (persistent panel's split tree).
- At any time, exactly one pane across both domains has application focus.
- ADDED: `AppModel.focusDomain: FocusDomain` — enum with `.workspace` and `.persistent` cases, tracking which domain currently has focus.

## Directional Focus (Cmd+Arrow)

- When the user invokes directional focus (focusPaneUp, focusPaneDown, focusPaneLeft, focusPaneRight), the system MUST consider panes from both domains.
- MODIFIED: `Workspace.focusPaneInDirection` (or a new top-level method) MUST compute pane rects for both the workspace detail area and the persistent panel area.
- Workspace pane rects MUST be mapped to the workspace detail's screen region (left portion).
- Persistent pane rects MUST be mapped to the persistent panel's screen region (right portion).
- The directional focus algorithm MUST find the nearest pane in the requested direction across both domains.
- If directional focus lands on a pane in a different domain, `focusDomain` MUST switch accordingly.
- If the persistent panel is hidden, its panes MUST NOT participate in directional focus.

## Sequential Cycling (Cmd+]/[)

- `focusNextPane` and `focusPreviousPane` MUST cycle only within the current focus domain.
- When focus is in the workspace domain, cycling MUST iterate through `workspace.allPanes`.
- When focus is in the persistent domain, cycling MUST iterate through `persistentNode.allPanes()`.
- Cycling MUST NOT cross the domain boundary.

## Focus Jump (Cmd+\)

- The `focusPersistentPanel` command MUST toggle focus between domains.
- When jumping to the persistent domain, the last-focused pane in the persistent panel MUST receive focus.
- When jumping to the workspace domain, the last-focused pane in the selected workspace MUST receive focus.
- Each domain MUST preserve its own focused pane ID independently.

## Sidebar Focus Interaction

- When the sidebar has focus (`sidebarHasFocus == true`), neither domain has terminal focus.
- Exiting sidebar focus (Enter on a pane, Escape) MUST restore focus to the appropriate domain based on which pane was confirmed or last focused.
- If Enter is pressed on a persistent pane row, `focusDomain` MUST switch to `.persistent`.
- If Enter is pressed on a workspace pane row, `focusDomain` MUST switch to `.workspace`.

## Focus Visual Indicators

- The focused pane in the active domain MUST show the standard focus border.
- Panes in the inactive domain MUST NOT show the focus border, even if they are the "last focused" pane in that domain.
- The persistent panel SHOULD show a subtle dimming overlay when it is not the active focus domain (matching the existing unfocused-pane dimming behavior).

## Split Actions and Focus

- When a split is performed in either domain, the newly created pane MUST receive focus within that domain.
- The `focusDomain` MUST remain unchanged after a split (the split happens in the domain that currently has focus).

## Pane Close and Focus

- When the focused pane in the active domain is closed, focus MUST move to an adjacent pane within the same domain.
- If the last pane in the persistent panel is closed, `focusDomain` MUST switch to `.workspace` automatically.
- If the last pane in the selected workspace is closed (a new default pane is created), focus MUST remain in the workspace domain.
