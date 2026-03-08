# Persistence

Hootty saves your entire workspace layout so everything is restored when you relaunch the app.

## What's Saved

All structural state is persisted to a single JSON file:

- **Workspaces** — names, IDs, and which workspace is selected.
- **Pane groups** — names, custom names, and which group is focused within each workspace.
- **Panes** — names, custom names, shell path, working directory, Claude session IDs, and which pane is selected within each group.
- **Split layout** — the full binary tree structure including split directions and ratios.
- **Sidebar width** — the user's preferred sidebar width.

## What's Not Saved

- **Terminal content** — scrollback buffers and on-screen text are not persisted. Each pane starts a fresh shell on launch.
- **Attention state** — attention indicators reset on restart.
- **Process state** — `isRunning` is determined at runtime by the shell process.

## Storage Location

Workspace state is stored at:

```
~/Library/Application Support/Hootty/workspaces.json
```

The theme selection is stored separately in macOS UserDefaults.

## When Saves Happen

- **Immediately** — after creating, deleting, or renaming workspaces, groups, or panes; after splitting or closing; and on app termination.
- **Debounced** — working directory changes and Claude session detections trigger a save with a 1-second debounce to coalesce rapid updates.

## Details

- The JSON file uses atomic writes to prevent corruption from interrupted saves.
- If the file is missing or corrupt on launch, Hootty creates a fresh session with one default workspace.
- Counters for auto-naming (e.g., "Workspace 3", "Group 2") are derived from the restored data, so numbering continues naturally.
