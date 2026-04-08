# Sidebar Badge Filters

## Overview

The sidebar header badge pills (thinking, flagged, done, bell) become tappable toggles that filter the pane list to show only panes matching the selected states.

## Filter Model

- ADDED: `SidebarFilter` enum in HoottyCore with cases `.thinking`, `.flagged`, `.done`, `.bell`.
- ADDED: `AppModel.activeSidebarFilters: Set<SidebarFilter>` property, defaulting to empty set.
- The filter state MUST be in-memory only (not persisted via WorkspaceStore).
- `AppModel` MUST provide `toggleSidebarFilter(_ filter: SidebarFilter)` using symmetric difference.
- `AppModel` MUST provide `clearSidebarFilters()` that empties the set.
- `AppModel` MUST expose `var isFilteringSidebar: Bool` computed as `!activeSidebarFilters.isEmpty`.

## Pane Matching

- ADDED: `Pane` MUST expose `func matches(_ filters: Set<SidebarFilter>) -> Bool`.
- When `filters` is empty, the method MUST return `true` (no filtering).
- When `filters` is non-empty, the method MUST return `true` if the pane matches ANY active filter (OR logic).
- `.thinking` MUST match panes where `isThinking == true`.
- `.flagged` MUST match panes where `isFlagged == true`.
- `.done` MUST match panes where `attentionKind == .done`.
- `.bell` MUST match panes where `attentionKind == .bell`.

## Focused Pane Pinning

- The focused pane of the selected workspace MUST always be visible in the sidebar, regardless of filter state.
- Specifically: when computing filtered pane lists, a pane MUST be included if it is the `focusedPaneID` of the selected workspace, even if it does not match any active filter.
- Non-selected workspaces MUST NOT pin their focused panes (only the active workspace gets pinning).

## Sidebar Header Badge Interaction

- Each badge pill (thinking, flagged, done, bell) MUST respond to tap/click gestures.
- Tapping a pill MUST toggle its corresponding `SidebarFilter` in `activeSidebarFilters`.
- The pill MUST have `.contentShape(Capsule())` to ensure the entire capsule area is tappable.
- The cursor MUST change to pointing hand on hover over a pill.

## Badge Visual States

Badges MUST have three visual states:

### Inactive (no filter, count == 0)
- Text and icon: `tokens.textMuted`
- Background: `tokens.textMuted` at 15% opacity
- No border

### Active count (no filter, count > 0)
- Text and icon: category color (e.g., `tokens.statusThinking`)
- Background: category color at 15% opacity
- No border

### Filter active
- Text and icon: category color (regardless of count)
- Background: category color at 30% opacity
- Border: 1pt category color at 60% opacity, capsule shape
- This state MUST apply whether the count is zero or non-zero

## Badge Counts

- Badge counts MUST always reflect the global aggregate across all workspaces, regardless of active filters.
- Badge counts MUST NOT be recalculated based on visible/filtered panes.
- The existing `AttentionCounts` aggregation logic MUST remain unchanged.

## Pane List Filtering

- MODIFIED: `WorkspaceSidebar.workspacePaneList` MUST filter `section.panes` before rendering rows.
- A pane MUST be shown if it matches the active filters OR is the pinned focused pane.
- When no filters are active, all panes MUST be shown (existing behavior).

## Branch Section Hiding

- When all panes in a `SidebarSection` are filtered out (none match and none are pinned), the section header MUST NOT be rendered.
- When at least one pane in a section is visible, the section header MUST be rendered normally.
- Branch section header badge counts (thinking/done/bell per section) MUST remain global to the section, unaffected by active filters.

## Workspace Row Visibility

- Workspace rows MUST always be visible, regardless of filter state.
- Workspace rows MUST NOT be filterable — they are structural, not attention-bearing.
- When a workspace is expanded but has zero visible panes after filtering, the workspace row MUST still appear (the empty state below it communicates "nothing matches here").

## Workspace Collapse Interaction

- Collapsed workspace rows MUST remain visible regardless of filter state.
- The `WorkspaceAttentionSummary` dot on collapsed rows MUST be unaffected by active filters — it always summarizes all child panes.
- Expanding a collapsed workspace while filters are active MUST show only matching panes (plus the pinned focused pane if applicable).

## Scroll Targets

- MODIFIED: `WorkspaceSidebar.scrollTargetIDs` MUST exclude pane IDs that are filtered out.
- Workspace IDs MUST always be included in scroll targets.
- The pinned focused pane MUST be included in scroll targets.

## Auto-Scroll on Focus Change

- The existing `onChange(of: selectedWorkspace?.focusedPaneID)` auto-scroll MUST continue to work because the focused pane is always pinned visible (its `.id()` is always in the ScrollView).
- No changes required to the auto-scroll logic.

## Keyboard Navigation

- MODIFIED: `SidebarKeyboardNav.allNavigableItems` MUST accept an `activeFilters: Set<SidebarFilter>` parameter (defaulting to empty set for backward compatibility).
- Pane items MUST be excluded from the navigable list if they don't match the active filters AND are not the pinned focused pane.
- Workspace items MUST always be included.
- If the keyboard cursor is on a pane that gets filtered out (e.g., its attention state changes), the cursor MUST clamp to the nearest visible item on the next move. The existing fallback behavior (snap to first item when current index not found) handles this.

## Escape Key Behavior

- MODIFIED: When the sidebar has focus and Escape is pressed:
  1. If filters are active: clear all filters. Sidebar MUST retain focus. Cursor position MUST be preserved.
  2. If no filters are active: defocus the sidebar (existing behavior).
- This creates a two-step Escape: first clears filters, then exits sidebar focus mode.

## Command Integration

- ADDED: `AppCommand.clearSidebarFilters` with title "Clear Sidebar Filters".
- The command MUST call `appModel.clearSidebarFilters()`.
- The command MUST appear in the command palette.
- The command MAY have no keyboard shortcut (Escape handles this contextually).
- The command SHOULD be hidden from the palette when no filters are active.
