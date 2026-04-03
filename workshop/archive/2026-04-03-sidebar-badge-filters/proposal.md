# Sidebar Badge Filters

## Why

The sidebar header already shows aggregate attention badges (thinking, flagged, done, bell) — but they're purely informational. When you have many panes across multiple workspaces, you can see that 3 panes need attention but you have to visually scan every row to find them. There's no way to narrow the sidebar list to just the panes you care about.

The badges are already the right visual vocabulary for pane states. Making them interactive gives users a way to quickly surface panes that need attention without adding new UI surface area.

## What Changes

- Sidebar header badge pills become tappable toggles that filter the pane list
- When one or more filters are active, only matching panes (plus the focused pane) are shown
- Empty branch sections and empty workspace pane lists collapse naturally
- Keyboard navigation, scroll targets, and auto-scroll adapt to filtered state
- Active filters are visually distinct from inactive badges (stronger fill + border ring)
- Escape key clears all active filters before defocusing the sidebar

## Capabilities

### New Capabilities

- **sidebar-badge-filters**: Tappable badge pills that filter the sidebar pane list by attention state (thinking, flagged, done, bell). OR logic — show panes matching any active filter. Focused pane is always pinned visible. Escape clears filters.

### Modified Capabilities

- **sidebar-keyboard-nav-workspaces**: `allNavigableItems` must accept active filters and exclude non-matching panes from the navigable list (preserving focused-pane pinning).
- **workspace-collapse**: Collapsed workspace rows remain visible regardless of filters. The attention summary dot on collapsed rows is unaffected by filter state.

## Impact

- **No persistence changes** — filter state is transient (in-memory only), not saved to WorkspaceStore
- **No new dependencies**
- **No API changes**
- **Model layer** — `SidebarFilter` enum and `Pane.matches(_:)` added to HoottyCore; `SidebarKeyboardNav` gains a filters parameter
- **View layer** — `WorkspaceSidebar` pill rendering, pane list filtering, scroll target computation, and Escape key handling updated
