# Sidebar

The sidebar shows a tree view of all your workspaces, pane groups, and panes, giving you an overview of your entire session and quick navigation between terminals.

## Usage

### Toggling visibility

Press `Cmd+Shift+S` or use **View > Show/Hide Sidebar** to toggle the sidebar.

### Resizing

Drag the divider between the sidebar and the main content area to resize. The sidebar width is constrained between 140pt and 400pt.

### Tree structure

The sidebar displays a three-level hierarchy:

1. **Workspaces** — top-level rows with a folder icon. Click the disclosure arrow to expand/collapse.
2. **Pane groups** — shown as folder rows when a group contains multiple panes. Single-pane groups are displayed inline (the pane appears directly under the workspace).
3. **Panes** — individual terminal sessions within multi-pane groups, connected by tree lines showing their relationship.

### Navigating

- Click a **workspace row** to select that workspace and expand it.
- Click a **group row** to focus that group within the workspace.
- Click a **pane row** to focus that pane (and its group).

### Hover interactions

Hovering over any row reveals a **close button** (X). Click it to close that workspace, group, or pane. The close button is hidden for items that can't be closed (e.g., the only group in a workspace or the only pane in a group).

### Context menus

Right-click for context-specific actions:

- **Workspace row** — Rename Workspace
- **Group row** — Rename Group, Close Group
- **Pane row** — Close Pane

## Details

- The sidebar width is persisted across app restarts.
- Selected rows have a solid highlight background; hovered rows have a subtle highlight.
- Attention indicators appear as animated borders on workspace and group rows when unfocused panes need attention (see [Attention Indicators](attention-indicators.md)).
- Focused panes show an accent-colored border in the sidebar.
- Tree connector lines are drawn between pane rows to indicate grouping within multi-pane groups.
