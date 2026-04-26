## ADDED Requirements

### Requirement: Workspace-level occlusion toggling
When the selected workspace changes, the system MUST call `ghostty_surface_set_occlusion(surface, false)` on every surface belonging to the previously selected workspace, and `ghostty_surface_set_occlusion(surface, true)` on every surface belonging to the newly selected workspace.

#### Scenario: Switch from workspace A to workspace B
- **WHEN** `selectedWorkspaceID` changes from workspace A to workspace B
- **THEN** all surfaces cached for workspace A's panes are marked occluded (`false`)
- **AND** all surfaces cached for workspace B's panes are marked visible (`true`)

#### Scenario: Select a workspace while window is occluded
- **WHEN** `selectedWorkspaceID` changes to workspace B while the window is not visible (e.g., minimized)
- **THEN** workspace B's surfaces MUST remain occluded (`false`) because the window-level occlusion takes precedence

#### Scenario: App launch with persisted workspace selection
- **WHEN** the app launches and restores a persisted `selectedWorkspaceID`
- **THEN** only the selected workspace's surfaces are marked visible; all other workspaces' surfaces are occluded

### Requirement: View-detach occlusion
When a `TerminalSurfaceView` is removed from its window (e.g., SwiftUI identity change during workspace switch), the system MUST mark the surface as occluded.

#### Scenario: Surface detached from window
- **WHEN** `viewDidMoveToWindow()` fires with `window == nil`
- **THEN** the system calls `ghostty_surface_set_occlusion(surface, false)`

#### Scenario: Surface reattached to visible window
- **WHEN** `viewDidMoveToWindow()` fires with a non-nil window whose `occlusionState` contains `.visible`
- **THEN** the system calls `ghostty_surface_set_occlusion(surface, true)`

#### Scenario: Surface reattached to occluded window
- **WHEN** `viewDidMoveToWindow()` fires with a non-nil window whose `occlusionState` does not contain `.visible`
- **THEN** the system calls `ghostty_surface_set_occlusion(surface, false)`

### Requirement: Terminal state preservation
Marking a surface as occluded MUST NOT affect the PTY, scrollback buffer, shell process, or any terminal state. Only Metal rendering is suppressed.

#### Scenario: Background workspace receives output
- **WHEN** a shell process in an occluded workspace produces output
- **THEN** the output is buffered in the ghostty surface's scrollback and is visible when the user switches back to that workspace

#### Scenario: Switch back to previously occluded workspace
- **WHEN** the user switches to a workspace whose surfaces were occluded
- **THEN** the terminal content is fully intact with no lost output, and the surface re-renders within one frame

### Requirement: Scoped refresh
The `refreshTerminal` command MUST only call `ghostty_surface_refresh` on surfaces belonging to the currently selected workspace, not on all cached surfaces.

#### Scenario: Refresh with background workspaces
- **WHEN** the user invokes `refreshTerminal`
- **THEN** only surfaces in the selected workspace are refreshed
- **AND** occluded surfaces in background workspaces are not woken up
