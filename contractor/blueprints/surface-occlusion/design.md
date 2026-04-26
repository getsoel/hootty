## Context

Hootty wraps libghostty, which manages a `ghostty_surface_t` per terminal pane. Each surface owns a PTY, VT parser, scrollback buffer, and a Metal renderer. The Metal renderer allocates GPU textures (frame buffers for double/triple buffering) and runs a render pass each tick.

Today, `ghostty_surface_set_occlusion(surface, bool)` is called only in response to `NSWindow.didChangeOcclusionStateNotification`. If the window is on-screen, all surfaces — across every workspace — report as visible. With 31 panes this means ~26 background surfaces render Metal frames every tick, consuming ~85 MB each and producing a ~140 MB oscillation from triple-buffered frame cycling.

SwiftUI uses `.id(workspace.id)` on the detail view, so switching workspaces tears down the view tree and rebuilds it. Surface NSViews survive in `GhosttyApp.surfaceViews` cache and are reattached via `TerminalPaneView.makeNSView`. However, when a view is detached (`viewDidMoveToWindow` with `window == nil`), the method returns early at the `guard let surface, let window` without marking the surface occluded.

## Goals / Non-Goals

**Goals:**
- Suppress Metal rendering for surfaces not currently displayed, proportionally reducing memory and GPU usage
- Preserve all terminal state (PTY, scrollback, shell process) for occluded surfaces
- Use the existing `ghostty_surface_set_occlusion` API with no libghostty changes

**Non-Goals:**
- Reducing per-surface base memory (scrollback buffers, VT state) — that requires libghostty config changes
- Lazy surface creation (deferring `ghostty_surface_new` until a workspace is first selected) — useful but separate
- Throttling the memory monitor or reducing its sampling frequency

## Decisions

### 1. Workspace-level occlusion via `GhosttyApp`

Add a method `setOcclusion(visible: Bool, for workspace: Workspace)` on `GhosttyApp` that iterates the workspace's `allPanes`, looks up each in `surfaceViews`, and calls `ghostty_surface_set_occlusion`. This centralizes the workspace↔surface mapping in the same object that already owns the cache.

**Alternative considered:** Passing occlusion state through SwiftUI environment. Rejected because the surfaces that need marking are the ones *not* in the view tree (background workspaces), so environment propagation can't reach them.

### 2. Trigger point: `onChange(of: selectedWorkspaceID)` in ContentView

Add an `onChange` modifier that calls `GhosttyApp.shared.setOcclusion(visible: false, ...)` for the old workspace and `setOcclusion(visible: true, ...)` for the new one. ContentView already has access to `appModel.workspaces` and `appModel.selectedWorkspaceID`.

**Alternative considered:** Observing `selectedWorkspaceID` from `GhosttyApp` directly. Rejected because GhosttyApp doesn't hold a reference to AppModel and shouldn't — it's a lower-level ghostty wrapper.

### 3. View-detach handling in `viewDidMoveToWindow`

Before the existing `guard let surface, let window else { return }`, add:

```
if window == nil, let surface {
    ghostty_surface_set_occlusion(surface, false)
    return
}
```

On reattach (window is non-nil), after the existing setup, respect the window's actual occlusion state instead of unconditionally treating the surface as visible. Replace the unconditional `ghostty_surface_refresh` with:

```
let windowVisible = window.occlusionState.contains(.visible)
ghostty_surface_set_occlusion(surface, windowVisible)
if windowVisible {
    ghostty_surface_refresh(surface)
}
```

This makes view-detach a belt-and-suspenders layer alongside workspace-level toggling. Both paths converge on the same `set_occlusion(false)` call, so redundant calls are harmless.

### 4. Scoped `refreshAllSurfaces`

Change `GhosttyApp.refreshAllSurfaces()` to accept an optional set of pane IDs. The `refreshTerminal` command passes the selected workspace's pane IDs. If no filter is provided (defensive), fall back to refreshing all — but the current sole caller always provides a scope.

**Alternative considered:** A separate `refreshVisibleSurfaces(workspace:)` method. Either works; a parameter on the existing method avoids proliferating API surface.

### 5. Window-level occlusion interaction

The existing `windowOcclusionDidChange` handler remains as-is. When the window is hidden (Command-H, minimize), it sets occlusion to `false` on all attached surfaces. When the window reappears, it sets `true` — but only for surfaces currently attached to the window (i.e., the selected workspace). Background workspace surfaces are not attached, so they stay occluded correctly.

## Risks / Trade-offs

**[Single-frame flash on workspace switch]** → When switching to a workspace, surfaces need one render pass to produce a current frame. The existing `ghostty_surface_refresh` call in `viewDidMoveToWindow` already handles this. If noticeable, a future enhancement could pre-render one frame before the SwiftUI transition, but this is unlikely to be perceptible.

**[Redundant occlusion calls]** → Both workspace-level toggling and view-detach fire `set_occlusion(false)`. This is intentional defense-in-depth. The ghostty API is idempotent — calling `set_occlusion(false)` on an already-occluded surface is a no-op.

**[Race between workspace switch and view teardown]** → SwiftUI's `.id()` change triggers view teardown asynchronously. The `onChange` handler fires synchronously. Both set occlusion to false for the old workspace. Order doesn't matter because both converge on the same state.
