# Design: Pane Flag Button

## Approach

Follow the existing note property pattern on `Pane` — add a simple boolean toggle with UI indicators in both the pane bar and sidebar. Wire through the established command system for palette and shortcut access.

The implementation touches four layers:
1. **Model** — `Pane.isFlagged` property + `toggleFlag()` method
2. **Pane bar** — `BarIconButton` in `PaneGroupTabBar` next to the existing note button
3. **Sidebar** — Flag icon + yellow background in `SidebarPaneRow`
4. **Commands** — `AppCommand.flagPane` + `CommandRegistry` registration

## Key Decisions

### In-memory only (no persistence)
Flag state is transient, matching notes. Flags are session markers, not permanent metadata. This avoids Codable changes and keeps the feature lightweight.

### Boolean toggle, not multi-state
A simple `isFlagged: Bool` rather than flag colors or categories. Keeps the UI and model simple. Multi-color flags could be added later if needed without breaking the toggle contract.

### `statusWarning` token for yellow color
Reuse the existing `tokens.statusWarning` (palette index 3, yellow) for the flag icon and sidebar highlight. This is consistent with the note system which also uses `statusNote` (same yellow). No new design token needed.

### Sidebar background: `statusWarning` at reduced opacity
Apply `statusWarning.withAlphaComponent(0.15)` as the row background to create a subtle highlight that doesn't obscure text. This is a new visual pattern for the sidebar (notes only show an icon, not a background), but justified by the "at a glance" goal.

### Keyboard shortcut: `Ctrl+Shift+G`
- `Ctrl+Shift+F` is taken (notePane)
- `Ctrl+Shift+G` is available and mnemonically close (F for flag, G is adjacent)
- Follows the modifier pattern of other pane commands

### Button placement in pane bar
Place the flag button immediately after the note button in the action group, before any trailing spacer. Both are pane-level markers, so grouping them makes sense.

### SF Symbol choice
- Unflagged: `"flag"` (outline)
- Flagged: `"flag.fill"` (filled)
This matches the filled/unfilled pattern used elsewhere for active states.

## Dependencies

None. Uses existing components:
- `BarIconButton` for the pane bar button
- `DesignTokens.statusWarning` for coloring
- `AppCommand` + `CommandRegistry` for command integration
