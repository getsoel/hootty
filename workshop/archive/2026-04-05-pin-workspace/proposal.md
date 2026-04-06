# Pin Workspace

## Why

The docked panel feature adds significant complexity (~800 lines) for a use case that's simpler than it appears. Users want a way to keep one workspace easily accessible — not a parallel terminal panel with its own split tree, resize handles, four-position layout, and cross-domain focus management. The current implementation introduces `FocusDomain`, `PanelPosition`, persistent node management, panel layout calculations, and 8 dedicated commands — all to solve "I want to quickly jump to my Claude workspace."

Replacing it with workspace pinning gives users the same quick-access benefit with far less conceptual overhead: pin a workspace, it stays at the top, press a shortcut to jump to it.

## What Changes

- Remove the entire persistent/docked panel system: `persistentNode`, `FocusDomain`, `PanelPosition`, panel layout in ContentView, panel resize drag handles, dock position menu, and all 8 dock-related commands
- Remove `PanelPosition.swift` and `FocusDomain.swift` files entirely
- Add a `pinnedWorkspaceID: UUID?` property to AppModel (persisted via WorkspaceStore)
- Sort pinned workspace to the top of the sidebar list with a visual pin indicator
- Add two commands: toggle pin on the selected workspace, and focus (switch to) the pinned workspace
- Simplify ContentView layout to remove panel frame calculations, dividers, and drag handles
- Simplify sidebar navigation to remove persistent pseudo-workspace handling

## Capabilities

### New Capabilities

- **pin-workspace-model**: Data model for pinning a workspace (single `pinnedWorkspaceID` on AppModel, persisted)
- **pin-workspace-sidebar**: Sidebar sorts pinned workspace to top with visual indicator; context menu to pin/unpin
- **pin-workspace-commands**: Two commands — "Pin/Unpin Workspace" (toggle) and "Focus Pinned Workspace" (switch)

### Modified Capabilities

- **Persistence (WorkspaceStore)**: Add optional `pinnedWorkspaceID` field to snapshot; remove all persistent panel fields
- **Sidebar navigation (SidebarNavigation)**: Remove persistent pseudo-workspace handling; pinned workspace is just a regular workspace sorted first
- **ContentView layout**: Remove panel layout, divider, drag handle rendering; detail area fills available space

## Impact

- **Persistence**: Snapshot format changes (fields removed, one added). Old snapshots with persistent panel fields will be silently ignored (optional decoding). New field absent in old snapshots means nothing pinned — clean migration both directions.
- **Commands**: 8 commands removed, 2 added. Users with muscle memory for `Cmd+Opt+P` (toggle docked panel) or `Cmd+\` (focus docked panel) will need to learn new shortcuts.
- **No other system impact**: No database, API, or dependency changes.
