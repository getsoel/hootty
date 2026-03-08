# Pane Groups

Pane groups are regions within a workspace, each with its own tab bar and set of terminal panes. When you split a workspace, you create a new pane group alongside the existing one.

## Usage

### Creating a pane group

Pane groups are created by splitting. Use the **Shell** menu or keyboard shortcuts to split the focused group into two regions:

- **Split Right** — `Cmd+D`
- **Split Down** — `Cmd+Shift+D`
- **Split Left** — `Cmd+Option+D`
- **Split Up** — `Cmd+Option+Shift+D`

You can also split from the split button in the tab bar, which offers a menu of all four directions.

A new workspace automatically starts with one pane group.

### Focusing a pane group

Click any terminal pane or tab within a group to focus that group. You can also click the group's row in the sidebar.

### Renaming a pane group

Right-click a group row in the sidebar and choose **Rename Group**. Enter a custom name or leave it blank to revert to the auto-generated name.

### Closing a pane group

Hover over a group row in the sidebar to reveal the close button, then click it. The close button is hidden if the group is the only one in its workspace.

You can also right-click and choose **Close Group** from the context menu.

## Details

- Groups are auto-named sequentially within their workspace: "Group 1", "Group 2", etc.
- Each group maintains its own selected pane (active tab), independent of other groups.
- In the sidebar, a group with a single pane is displayed inline (showing the pane directly). Groups with multiple panes show as an expandable folder with pane children.
- The new group created by a split inherits the shell and working directory of the currently selected pane.
- Attention indicators on pane groups aggregate from their panes — the most urgent kind (input over idle) is shown.
- When a group gains focus, the selected pane's attention indicator is automatically cleared.
