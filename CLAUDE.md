# Hootty

macOS terminal emulator — SwiftUI app (macOS 14+) powered by libghostty for terminal emulation and Metal rendering.

## Setup
After cloning, run `make setup` to configure git hooks (pre-commit runs build + tests).

## Commands
- `swift build`: compile
- `swift test`: run unit tests (HoottyCoreTests)
- `swift test --filter TestName`: run a single test
- `swift run Hootty`: launch app (window appears with zsh session)

## Architecture
```
Sources/
  CGhostty/
    include/ghostty.h          -- vendored libghostty C headers
    include/module.modulemap   -- SPM module map
    shims.c                    -- placeholder for SPM
  HoottyCore/                -- testable library target (no UI dependencies)
    AppModel.swift             -- @Observable app state, workspace management
    Workspace.swift            -- @Observable: id, name, rootNode (SplitNode), focusedPaneGroupID
    PaneGroup.swift            -- @Observable: id, name, rootNode (SplitNode), focusedPaneID
    Pane.swift                 -- @Observable: id, name, isRunning, shell, workingDirectory
    SplitNode.swift            -- @Observable binary tree: leaf(Pane) | split(direction, first, second)
    TerminalTheme.swift        -- Catppuccin themes (palette definitions)
    ThemeManager.swift         -- Persisted theme selection
  Hootty/
    HoottyApp.swift          -- @main entry, initializes GhosttyApp
    Views/
      ContentView.swift        -- HStack: sidebar + detail (terminal view)
      WorkspaceSidebar.swift   -- Workspace list with status indicators
      PaneGroupTabBar.swift     -- Tab strip within a pane group region
      PaneGroupView.swift      -- Per-region pane group container (tab bar + split content)
      SplitView.swift          -- Recursive SplitNodeView rendering split panes with dividers
      TerminalPaneView.swift   -- NSViewRepresentable wrapping TerminalSurfaceView per Pane
    Terminal/
      GhosttyApp.swift         -- Singleton ghostty_app_t wrapper, runtime callbacks
      TerminalSurfaceView.swift -- NSView hosting ghostty_surface_t (Metal rendering, keyboard/mouse input)
Tests/
  HoottyCoreTests/           -- unit tests for model logic
Vendors/
  lib/libghostty.a             -- pre-built libghostty static library
```

Uses [libghostty](https://github.com/ghostty-org/ghostty) for full terminal emulation (PTY, ANSI/VT parsing, Metal rendering, Kitty keyboard protocol).

Rebuilding libghostty: see `docs/REBUILDING.md`

### Data flow
- ghostty_app_t (singleton) → manages config and dispatches actions via callbacks
- ghostty_surface_t (per pane) → handles PTY, parsing, and Metal rendering internally
- TerminalSurfaceView (NSView) → hosts the surface, forwards keyboard/mouse events
- Action callbacks (title, pwd, exit) → update Pane model → PaneGroup aggregates → SwiftUI reacts
- Split panes: PaneGroup.rootNode is a SplitNode binary tree; each leaf holds a Pane with its own surface

Debugging/logging: see `docs/DEBUGGING.md` (read when investigating crashes or runtime issues)

### Naming: Tab vs Pane vs Group
- **Tab**: UI presentation concept — items in the tab bar. Use in tab bar context: "Rename Tab", "Close Tab"
- **Pane**: The underlying terminal session. Use in sidebar tree and split contexts: "Close Pane", "Split Pane"
- **Group** / **PaneGroup**: Container of panes shown as a region with its own tab bar. Use in sidebar: "Close Group"

## Before Finishing
- `swift build` succeeds
- `swift test` passes (ignore signal 10 exit — see CLAUDE.local.md)
- Only task-relevant files changed
