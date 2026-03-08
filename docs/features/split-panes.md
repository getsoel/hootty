# Split Panes

Split panes let you view multiple pane groups side by side within a single workspace. Splits arrange groups in a recursive binary tree, so you can create complex multi-pane layouts.

## Usage

### Splitting

Split the focused pane group using the **Shell** menu or keyboard shortcuts:

| Action | Shortcut |
|--------|----------|
| Split Right | `Cmd+D` |
| Split Down | `Cmd+Shift+D` |
| Split Left | `Cmd+Option+D` |
| Split Up | `Cmd+Option+Shift+D` |

You can also use the **split button** in the tab bar, which opens a menu with all four directions.

- **Right/Left** create horizontal (side-by-side) splits.
- **Down/Up** create vertical (stacked) splits.
- The new group appears in the specified direction relative to the focused group.

### Resizing splits

Drag the divider between two split regions to resize them. The divider has a thin visible line with a wider invisible drag handle for easy grabbing.

Split ratios are clamped between 10% and 90%, so neither side can be collapsed entirely.

### Closing a split

Close a pane group (by closing all its tabs or via the sidebar) to collapse the split. The remaining group expands to fill the space.

## Details

- Splits default to a 50/50 ratio.
- Split ratios are persisted and restored across app restarts.
- The new group inherits the shell and working directory of the currently selected pane.
- You can nest splits to any depth — for example, split right, then split the right group down, then split that group right again.
- The resize cursor changes to indicate the drag direction (horizontal or vertical).
- Divider position updates live as you drag, with the final ratio committed when you release.
