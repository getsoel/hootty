# Hootty

macOS terminal emulator — SwiftUI app (macOS 14+) powered by libghostty for terminal emulation and Metal rendering.

## Setup
After cloning, run `make setup` to configure git hooks (pre-commit runs build + tests).

## Commands
- `make build`: compile (uses xcodebuild for proper xcassets compilation)
- `make run`: build + launch app
- `make debug`: build + launch with log streaming
- `swift test`: run unit tests (HoottyCoreTests)
- `swift test --filter TestName`: run a single test

## Architecture
```
Sources/
  CGhostty/
    include/ghostty.h          -- vendored libghostty C headers
    include/module.modulemap   -- SPM module map
    shims.c                    -- placeholder for SPM
  HoottyCore/                -- testable library target (no UI dependencies)
    AppModel.swift             -- @Observable app state, workspace management
    Workspace.swift            -- @Observable: id, name, rootNode (SplitNode), focusedPaneID
    Pane.swift                 -- @Observable: id, name, isRunning, shell, workingDirectory
    SplitNode.swift            -- @Observable binary tree: leaf(Pane) | split(direction, first, second)
    WorkspaceStore.swift       -- Persistence: save/load workspaces to disk
    DesignTokens.swift         -- Semantic color/spacing tokens (see docs/DESIGN.md)
    TerminalTheme.swift        -- Catppuccin themes (palette definitions)
    ThemeManager.swift         -- Persisted theme selection
  Hootty/
    HoottyApp.swift          -- @main entry, initializes GhosttyApp
    HoottyBundle.swift         -- shared SPM resource bundle resolver (use for all bundled resources)
    CrashHandler.swift         -- Crash log writer (~/Library/Logs/Hootty/)
    Log.swift                  -- os.Logger wrapper (subsystem: com.soel.hootty)
    Views/
      ContentView.swift        -- HStack: sidebar + detail (terminal view)
      WorkspaceSidebar.swift   -- Workspace list with status indicators
      PaneGroupTabBar.swift     -- Tab strip within a pane group region
      PaneGroupView.swift      -- Per-region pane group container (tab bar + split content)
      SplitView.swift          -- Recursive SplitNodeView rendering split panes with dividers
      TerminalPaneView.swift   -- NSViewRepresentable wrapping TerminalSurfaceView per Pane
      AnimatedBorderModifier.swift -- Animated gradient border for attention state
      CatppuccinIcons.swift    -- Catppuccin SVG icon views
      LucideIcon.swift         -- Lucide icon helper
      StatusDotView.swift      -- Colored status dot indicator
      WindowAccessor.swift     -- NSWindow access from SwiftUI
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
- Action callbacks (title, pwd, exit) → update Pane model → Workspace aggregates → SwiftUI reacts
- Split panes: Workspace.rootNode is a SplitNode binary tree; each leaf holds a Pane with its own surface

Debugging/logging: see `docs/DEBUGGING.md` (read when investigating crashes or runtime issues)
Claude Code hooks: see `docs/HOOKS.md` (read when modifying the wrapper script, env var injection, or attention indicators)

### Naming: Tab vs Pane vs Group
- **Tab**: UI presentation concept — items in the tab bar. Use in tab bar context: "Rename Tab", "Close Tab"
- **Pane**: The underlying terminal session. Use in sidebar tree and split contexts: "Close Pane", "Split Pane"
- **Group** / **PaneGroup**: Container of panes shown as a region with its own tab bar. Use in sidebar: "Close Group"

## Before Finishing
- `make build` succeeds
- `swift test` passes (ignore signal 10 exit — see CLAUDE.local.md)
- Only task-relevant files changed
