# Tabs

Each pane group has a tab bar at the top. Tabs represent individual terminal panes within a group, letting you switch between multiple sessions without splitting.

## Usage

### Creating a new tab

- Press `Cmd+T` or click the **+** button in the tab bar.
- The new tab inherits the working directory of the currently active pane.

### Switching tabs

- **Click** a tab to select it.
- Use the **left/right arrow buttons** at the edges of the tab bar to cycle through tabs.
- Tab cycling wraps around — going past the last tab selects the first, and vice versa.

### Renaming a tab

Right-click a tab and choose **Rename Tab**. Enter a custom name in the dialog. Leave it blank to revert to the automatic name (set by the shell's title sequence).

### Closing a tab

Hover over a tab to reveal its **close button** (X), then click it. If you close the last tab in a group, the entire group is removed.

### Reordering tabs

Drag a tab left or right within the tab bar to reorder it. The tab snaps into its new position as you drag over other tabs.

### Tab bar scrolling

When there are more tabs than fit in the bar, the tab area scrolls horizontally. Arrow buttons at the edges indicate overflow. Scrolling with the mouse wheel (vertical or horizontal) navigates the tab list.

## Details

- Tabs display up to 200pt of text before truncating with an ellipsis.
- Each tab shows a status indicator on the left:
  - **Green play icon** — the shell process is running.
  - **Bell icon** — the pane needs attention (see [Attention Indicators](attention-indicators.md)).
  - **No icon** — the process has exited.
- Tabs with attention show an animated colored border.
- The close button is hidden when not hovering to keep the tab bar clean.
- The active tab has a distinct background color to differentiate it from inactive tabs.
