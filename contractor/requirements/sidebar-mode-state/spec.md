# Sidebar Mode State

## Overview

Replaces the boolean `sidebarVisible` with a three-value `SidebarMode` enum, enabling the condensed sidebar rail as an intermediate state.

## Behavior

### SidebarMode Enum

- ADDED: `SidebarMode` enum in `HoottyCore` with cases `.full`, `.condensed`, `.hidden`.
- The enum MUST conform to `String`, `Codable`, and `Sendable`.
- MODIFIED: `AppModel.sidebarVisible: Bool` → REMOVED.
- ADDED: `AppModel.sidebarMode: SidebarMode`, defaulting to `.full`.

### Toggle Behavior

- MODIFIED: `AppModel.toggleSidebar()` MUST cycle: `.full` → `.condensed` → `.hidden` → `.full`.
- The toggle MUST call `saveWorkspaces()` after changing state.
- The `focusSidebar` command MUST set `sidebarMode` to `.full` (not `.condensed`) when activating.

### ContentView Layout

- MODIFIED: `ContentView.workspacesContent` MUST compute sidebar width based on mode:
  - `.full`: `effectiveSidebarWidth` (existing resizable behavior).
  - `.condensed`: `Layout.condensedSidebarWidth` (fixed).
  - `.hidden`: `0`.
- When mode is `.condensed`, `ContentView` MUST render `CondensedSidebar` instead of `WorkspaceSidebar`.
- When mode is `.condensed`, the drag handle divider MUST NOT appear.
- Animation between modes SHOULD use `.easeInOut(duration: 0.2)`.

### Persistence

- ADDED: `WorkspaceSnapshot.sidebarMode: SidebarMode?` optional field.
- MODIFIED: `WorkspaceSnapshot.sidebarVisible: Bool?` MUST remain for backward compatibility decoding but MUST NOT be written on new saves.
- On decode: if `sidebarMode` is present, use it. If absent but `sidebarVisible` is present, map `true` → `.full`, `false` → `.hidden`. If both absent, default to `.full`.
- On encode: MUST write `sidebarMode`. MUST NOT write `sidebarVisible`.

### Menu and Commands

- MODIFIED: The View menu button label MUST reflect the current mode:
  - `.full` → "Condense Sidebar"
  - `.condensed` → "Hide Sidebar"
  - `.hidden` → "Show Sidebar"
- The keyboard shortcut `⇧⌘S` MUST remain unchanged.
- `AppCommand.toggleSidebar` title MAY remain "Toggle Sidebar".

### Layout Constant

- ADDED: `Layout.condensedSidebarWidth: CGFloat` constant.
