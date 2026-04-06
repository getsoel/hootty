# Pin Workspace — Design

## Approach

This is primarily a removal with a small addition. The strategy is:

1. **Remove all docked panel code** from model, persistence, views, sidebar, navigation, and commands
2. **Delete `PanelPosition.swift` and `FocusDomain.swift`** — no longer needed
3. **Add `pinnedWorkspaceID: UUID?`** to AppModel with persistence
4. **Add sidebar sorting** — pinned workspace renders first
5. **Add two commands** to replace eight

The ContentView layout simplifies dramatically: the detail area is just a single workspace view filling the space next to the sidebar. No panel frames, no dividers, no drag handles.

## Key Decisions

### Single pinned workspace (not a set)
Using `pinnedWorkspaceID: UUID?` instead of `Set<UUID>`. One pin is enough for the "quick access" use case, and it avoids questions about sort order among multiple pins. If multiple pins are ever wanted, migrating from `UUID?` to `[UUID]` is trivial.

### Sort at render time, not in the array
The `workspaces` array order is the user's drag-and-drop order. Pinning doesn't mutate the array — the sidebar computes display order by putting the pinned workspace first and the rest in array order. This means unpinning restores the workspace to its original position.

### Reuse Cmd+\ for focus pinned
The existing `focusDockedPanel` shortcut (Cmd+\\) maps naturally to `focusPinnedWorkspace`. Users with muscle memory keep a similar shortcut for a similar purpose.

### No pin indicator in condensed sidebar rail
The condensed sidebar shows workspace icons in a vertical rail. Adding a pin indicator there adds complexity for minimal value — the pinned workspace is already sorted first. The pin icon only appears in the full sidebar row.

### Cleanup of `onMovePaneToPinned` callback naming
The existing sidebar code already uses "pinned" naming for the move-to-docked callback (`onMovePaneToPinned`). This gets removed entirely since there's no pane movement between domains.

### Test cleanup
Remove persistent panel integration tests. Add tests for: pin/unpin toggle, pinned workspace deletion clears pin, persistence round-trip of `pinnedWorkspaceID`.

## Dependencies

No new dependencies. This change only removes code and adds a property + two commands using existing patterns.
