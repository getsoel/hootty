# Design: Sidebar Badge Filters

## Approach

Add a `SidebarFilter` enum and filter state to `AppModel`, a matching predicate on `Pane`, and wire filtering into the existing sidebar rendering pipeline. The badge pills gain tap gestures and a third visual state. Keyboard navigation and scroll targets are updated to respect the filtered pane list.

The design preserves the existing badge counting logic untouched — badges always show global truth. Filtering only affects which pane rows render in `workspacePaneList()`.

## Key Decisions

### OR logic for multiple filters
When multiple filters are active (e.g., thinking + done), show panes matching ANY filter. This matches the mental model: "show me everything that needs attention." AND logic would be nearly useless — a pane is rarely both thinking and flagged simultaneously.

### Focused pane pinning (selected workspace only)
The focused pane of the selected workspace is always visible regardless of filters. This prevents the disorientation of your active pane disappearing from the sidebar. Only the selected workspace gets pinning — non-selected workspaces don't have an active context to preserve, and pinning their focused panes would add noise.

### Badges show global counts, not filtered counts
Badge counts represent system-wide truth: "3 panes are thinking." Changing counts based on what's visible would make them unreliable and circular (the badge drives the filter which drives the badge). The counts also serve as a signal for what you'll find when toggling a filter — "click thinking to see those 3 panes."

### Filter state on AppModel, not WorkspaceSidebar
Filters are cross-workspace (they affect all workspaces simultaneously) and need to be accessible from keyboard nav, commands, and potentially future features. `AppModel` already holds `collapsedWorkspaceIDs` and `sidebarHasFocus` — filter state is the same category of transient sidebar UI state.

### Two-step Escape (clear filters, then defocus)
Escape clears filters first because it's the lowest-friction way to reset. If Escape immediately defocused the sidebar (and cleared filters as a side effect), you'd lose your cursor position. The two-step approach lets you clear filters while staying in keyboard nav mode, then Escape again to exit.

### No persistence
Filter state is transient — like a search query. Restoring "filter to done panes" on next launch would be surprising, especially since the pane states themselves (attention, thinking) are also transient.

### `SidebarFilter` is a separate enum from `AttentionKind`
`AttentionKind` has `.bell` and `.done` but not `.thinking` or `.flagged` — those are independent pane properties. A dedicated `SidebarFilter` enum with all four cases avoids conflating unrelated types. The matching logic on `Pane` maps each filter case to the appropriate property.

### Filter in the view layer, not the model
`Workspace.sidebarSections` remains unfiltered — it's a model-level grouping concern. Filtering happens in `workspacePaneList()` at render time. This keeps the model clean and avoids propagating view-specific filter state through `Workspace` and `SidebarSection`.

### Branch section headers hide when empty
When filtering removes all panes in a branch section, rendering the header alone would be visual noise with no actionable content. Hiding it keeps the filtered sidebar clean. The header reappears as soon as a pane in that section matches.

### `allNavigableItems` gets a filters parameter with default
Adding `activeFilters: Set<SidebarFilter> = []` as a default parameter maintains backward compatibility — existing call sites in tests and anywhere else don't need updating. Only the `WorkspaceSidebar` call site passes the actual filters.

### Active filter visual: stronger fill + border ring
The current pills have "muted" (count 0) and "colored" (count > 0) states. Active filter adds a third state: stronger fill (0.3 vs 0.15) + 1pt capsule border at 0.6 opacity. This is clearly distinct from both existing states without redesigning the pill. The border is the unambiguous "toggled on" signal.

## Dependencies

No new dependencies. All changes use existing HoottyCore types and SwiftUI primitives.

## Files Changed

| File | Layer | Change |
|------|-------|--------|
| `Sources/HoottyCore/SidebarFilter.swift` | Model | New file: `SidebarFilter` enum |
| `Sources/HoottyCore/AppModel.swift` | Model | `activeSidebarFilters`, `toggleSidebarFilter()`, `clearSidebarFilters()`, `isFilteringSidebar` |
| `Sources/HoottyCore/Pane.swift` | Model | `matches(_:)` method |
| `Sources/HoottyCore/SidebarNavigation.swift` | Model | `activeFilters` parameter on `allNavigableItems()` |
| `Sources/HoottyCore/AppCommand.swift` | Model | `clearSidebarFilters` case |
| `Sources/Hootty/Views/WorkspaceSidebar.swift` | View | Pill tap gestures, active filter visuals, pane filtering in `workspacePaneList()`, filtered `scrollTargetIDs`, Escape key two-step |
| `Sources/Hootty/Views/ContentView.swift` | View | Pass `activeSidebarFilters` binding to sidebar |
| `Sources/Hootty/HoottyApp.swift` | App | Register `clearSidebarFilters` command |
| `Tests/HoottyCoreTests/` | Test | Filter matching, keyboard nav with filters, filter toggle/clear |
