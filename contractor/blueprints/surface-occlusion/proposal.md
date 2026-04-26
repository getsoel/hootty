## Why

With 31 open panes Hootty consumes ~2600 MB because every ghostty surface reports itself as visible regardless of which workspace is selected. libghostty runs Metal render passes for all 31 surfaces every tick — including the ~26 that belong to background workspaces and are never displayed. The existing `ghostty_surface_set_occlusion` API already exists to suppress rendering, but it is only wired to the window-level `NSWindow.didChangeOcclusionStateNotification`, so surfaces are only marked occluded when the entire window is hidden.

## What Changes

- Mark surfaces as occluded when their workspace is not the selected workspace. When `selectedWorkspaceID` changes, iterate the deselected workspace's surfaces and call `ghostty_surface_set_occlusion(surface, false)`, then mark the newly selected workspace's surfaces as visible.
- Mark surfaces as occluded when they are detached from the window. `viewDidMoveToWindow()` currently returns early when `window == nil` without informing ghostty. Add an explicit `ghostty_surface_set_occlusion(surface, false)` call on detach, and respect the window's actual occlusion state on reattach.
- Scope `refreshTerminal` (the manual refresh command) to only refresh surfaces in the currently selected workspace, not all cached surfaces.

## Capabilities

### New Capabilities
- `surface-occlusion`: Per-surface visibility tracking that tells libghostty which surfaces need Metal rendering. Covers workspace-level toggling, view-detach handling, and the interaction with `refreshTerminal`.

### Modified Capabilities
_(none — no existing requirement specs change at the behavior level)_

## Impact

**Code:**
- `Sources/Hootty/Terminal/TerminalSurfaceView.swift` — `viewDidMoveToWindow()` gains an occlusion call on detach; reattach path respects window occlusion state before calling `set_occlusion(true)`.
- `Sources/Hootty/Terminal/GhosttyApp.swift` — New method to set occlusion on all surfaces for a given workspace. `refreshAllSurfaces()` scoped to visible workspace only.
- `Sources/Hootty/Views/ContentView.swift` or `Sources/Hootty/HoottyApp.swift` — `onChange(of: selectedWorkspaceID)` triggers workspace-level occlusion toggling.

**APIs:** Uses existing `ghostty_surface_set_occlusion(ghostty_surface_t, bool)` from libghostty. No new C API needed.

**Dependencies:** None.

**User-visible behavior:** No visible change when using the app normally. Background workspace terminals continue running (PTY, scrollback, shell process are unaffected by occlusion). Switching back to a workspace may show a single-frame re-render as Metal catches up — identical to the existing behavior when the window is un-minimized.
