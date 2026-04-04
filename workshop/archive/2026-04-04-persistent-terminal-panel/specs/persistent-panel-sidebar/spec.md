# Persistent Panel Sidebar

## Overview

The persistent panel's panes appear in the left sidebar as a pseudo-workspace pinned to the top, using a pin icon instead of a folder icon.

## Pseudo-Workspace Row

- The persistent panel MUST appear as the first entry in the sidebar workspace list, above all regular workspaces.
- The row MUST use the SF Symbol `"pin.fill"` instead of `"folder.fill"` / `"folder.open.fill"`.
- The row MUST display the label "Pinned".
- The row MUST NOT be reorderable via drag-and-drop.
- The row MUST NOT be deletable via context menu or swipe.
- The row MUST NOT be renamable.
- The row MUST only be visible when `persistentNode` is not `nil` (i.e., the panel has at least one pane).

## Visual Separator

- A subtle horizontal divider SHOULD appear between the persistent pseudo-workspace and the regular workspace list to visually distinguish them.
- The divider MUST use `tokens.border` color.

## Row Selection

- Clicking the persistent pseudo-workspace row MUST NOT change `selectedWorkspaceID`.
- Clicking the row SHOULD toggle the panel's expanded/collapsed state in the sidebar (showing/hiding its pane list).
- The row MUST NOT have a "selected" background state tied to `selectedWorkspaceID`.

## Pane List

- When the pseudo-workspace is expanded, its panes MUST be rendered using the existing `SidebarPaneRow` component.
- Pane rows MUST show the same status indicators (thinking, attention, flag, note) as workspace panes.
- Pane rows MUST show tree connector lines matching the workspace pane tree style.
- Clicking a pane row MUST focus that pane in the persistent panel (`appModel.persistentFocusedPaneID`).
- Clicking a pane row MUST also make the persistent panel visible if it is hidden.

## Context Menu

- The persistent pseudo-workspace row context menu MUST include "New Pane" to add a pane to the panel.
- The persistent pseudo-workspace row context menu MUST include "Close All" to remove all persistent panes (setting `persistentNode` to `nil`).
- Individual pane rows in the persistent section MUST include "Close Pane" in their context menu.
- Individual pane rows MUST include "Move to Workspace" with a submenu of available workspaces.

## Attention Summary

- When the persistent pseudo-workspace is collapsed in the sidebar, the row MUST show a `StatusDotView` summarizing child pane attention (same pattern as collapsed workspace rows).
- When expanded, individual pane rows handle their own status indicators.

## Collapse/Expand

- The persistent pseudo-workspace MUST support collapse/expand in the sidebar independently of regular workspaces.
- The collapse state MAY be stored separately from `collapsedWorkspaceIDs` (e.g., `persistentSidebarCollapsed: Bool` on `AppModel`).
- Left/right arrow keys on the persistent workspace row in keyboard nav MUST toggle collapse/expand.

## Badge Filter Integration

- MODIFIED: Persistent panel panes MUST participate in sidebar badge filter matching.
- When filters are active, persistent pane rows MUST be filtered using the same logic as workspace pane rows.
- The focused persistent pane MUST be pinned visible (matching the workspace focused-pane pinning behavior).

## Keyboard Navigation

- MODIFIED: `SidebarKeyboardNav.allNavigableItems` MUST include the persistent pseudo-workspace and its panes at the top of the navigable list.
- The persistent workspace row MUST use `SidebarNavItem.workspace(persistentWorkspaceID)` where `persistentWorkspaceID` is a stable sentinel UUID.
- The persistent pane rows MUST use `SidebarNavItem.pane(workspaceID: persistentWorkspaceID, paneID:)`.
- Enter on the persistent workspace row SHOULD toggle its sidebar collapse state (not select a workspace).
