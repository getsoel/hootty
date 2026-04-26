## 1. View-detach occlusion

- [x] 1.1 In `TerminalSurfaceView.viewDidMoveToWindow()`, before the existing `guard let surface, let window` line, add a branch that calls `ghostty_surface_set_occlusion(surface, false)` and returns when `window == nil` and `surface != nil`
- [x] 1.2 On the reattach path (window is non-nil), replace the unconditional `ghostty_surface_refresh(surface)` with an occlusion-aware check: read `window.occlusionState.contains(.visible)`, call `ghostty_surface_set_occlusion(surface, visible)`, and only call `ghostty_surface_refresh` if visible

## 2. Workspace-level occlusion API

- [x] 2.1 Add `func setOcclusion(visible: Bool, for workspace: Workspace)` to `GhosttyApp` that iterates `workspace.allPanes`, looks up each in `surfaceViews`, and calls `ghostty_surface_set_occlusion` on the surface
- [x] 2.2 Add `onChange(of: appModel.selectedWorkspaceID)` in `ContentView` that calls `setOcclusion(visible: false)` for the old workspace and `setOcclusion(visible: true)` for the new workspace

## 3. Scoped refresh

- [x] 3.1 Change `GhosttyApp.refreshAllSurfaces()` to accept an optional `paneIDs: Set<UUID>?` parameter; when provided, only refresh surfaces whose pane ID is in the set
- [x] 3.2 Update the `refreshTerminal` command registration in `HoottyApp.swift` to pass the selected workspace's pane IDs to `refreshAllSurfaces`

## 4. Verification

- [x] 4.1 `make build` succeeds
- [x] 4.2 `swift test` passes
- [x] 4.3 `make format-check` passes
- [x] 4.4 `make lint` passes
- [-] 4.5 Manual verification: launch with multiple workspaces, confirm memory drops when switching away from a workspace with many panes, and confirm terminal content is intact when switching back
