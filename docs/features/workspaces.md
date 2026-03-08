# Workspaces

Workspaces are the top-level containers in Hootty. Each workspace holds one or more pane groups arranged in a split layout, giving you isolated environments for different projects or contexts.

## Usage

### Creating a workspace

Click the **+** button at the bottom of the sidebar to add a new workspace. Each new workspace starts with a single pane group containing one terminal pane.

### Selecting a workspace

Click a workspace row in the sidebar to switch to it. The selected workspace's pane groups and terminal content appear in the main area.

### Renaming a workspace

Right-click a workspace row in the sidebar and choose **Rename Workspace**. Enter the new name in the dialog and confirm.

### Deleting a workspace

Hover over a workspace row in the sidebar to reveal the close button, then click it. If you delete the currently selected workspace, the next available workspace is automatically selected.

### Expanding and collapsing

Click the disclosure arrow on a workspace row to expand or collapse its tree of pane groups and panes in the sidebar.

## Details

- A workspace always contains at least one pane group. If you close the last group, a fresh one is created automatically.
- New workspaces are named sequentially: "Workspace 1", "Workspace 2", etc.
- The selected workspace and its full tree structure are persisted across app restarts.
- Attention indicators bubble up from individual panes through groups to the workspace level. A collapsed workspace row shows an animated border if any unfocused pane inside it needs attention.
