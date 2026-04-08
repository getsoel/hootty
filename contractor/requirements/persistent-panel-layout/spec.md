# Persistent Panel Layout

## Overview

A right-side panel in `ContentView` that renders its own `SplitNode` tree via `SplitNodeView`, independent of the selected workspace. Resizable via a draggable divider.

## Panel Position

- The persistent panel MUST render to the right of the workspace detail area.
- The layout order MUST be: left sidebar | workspace detail | persistent panel.
- The panel MUST span the full height of the main content area (below the title bar).

## Layout Calculation

- The panel MUST use the same ZStack + absolute positioning pattern as the left sidebar.
- When `persistentPanelVisible` is `true`, the detail area width MUST be reduced by `persistentPanelWidth + 1` (1px divider).
- When `persistentPanelVisible` is `false`, the detail area MUST occupy all remaining width (existing behavior).
- The panel MUST be positioned at `x = fullWidth - persistentPanelWidth`.

## Divider

- A 1px vertical divider MUST appear between the workspace detail and the persistent panel, using `tokens.border` color.
- An invisible 16px drag handle MUST overlay the divider for resize interaction.
- The drag handle MUST show `NSCursor.resizeLeftRight` on hover.
- Resizing MUST use `@GestureState` for the in-flight delta (same pattern as the left sidebar divider).
- The panel width MUST be clamped to `[persistentPanelMinWidth, persistentPanelMaxWidth]` during and after drag.
- On drag end, the new width MUST be committed to `appModel.persistentPanelWidth` and `debouncedSave()` MUST be called.

## Panel Content

- The panel MUST render `SplitNodeView` with `appModel.persistentNode` as the root node.
- The panel MUST pass `appModel.persistentFocusedPaneID` as the focused pane ID.
- Split/close/focus callbacks on the panel's `SplitNodeView` MUST operate on the persistent node, not any workspace.
- The panel MUST support vertical splits within it. Horizontal splits MAY also be supported (reuse existing `SplitNodeView` which handles both directions).

## Visibility Animation

- Showing/hiding the persistent panel SHOULD animate with `.easeInOut(duration: 0.2)`, matching the left sidebar animation.
- The animation MUST be driven by `appModel.persistentPanelVisible`.

## Empty State

- When `persistentNode` is `nil` and the panel is toggled visible, a new pane MUST be created automatically (handled by model layer).
- The panel MUST NOT render when `persistentPanelVisible` is `false` or `persistentNode` is `nil`.

## Surface Cleanup

- When panes are closed in the persistent panel, `GhosttyApp.shared.removeCachedSurfaceView(for:)` MUST be called, matching workspace pane cleanup behavior.
