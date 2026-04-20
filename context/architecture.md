# Architecture

Use when: navigating Sources/, tracing data flow, or locating a file by responsibility.

## Tree

```
Sources/
  CGhostty/
    include/ghostty.h          -- vendored libghostty C headers
    include/module.modulemap   -- SPM module map
    shims.c                    -- placeholder for SPM
  HoottyCore/                  -- testable library target (no UI dependencies)
    AppModel.swift             -- @Observable app state, workspace/theme/sound management
    Workspace.swift            -- @Observable: id, name, rootNode (SplitNode), focusedPaneID
    Pane.swift                 -- @Observable: id, name, isRunning, shell, workingDirectory
    SplitNode.swift            -- @Observable binary tree: leaf(Pane) | split(direction, first, second)
    WorkspaceStore.swift       -- Persistence: save/load workspaces to disk
    DesignTokens.swift         -- Semantic color/spacing tokens (see context/design.md)
    TerminalTheme.swift        -- Catppuccin themes (palette definitions)
    ThemeManager.swift         -- Persisted theme selection
    ThemeCatalog.swift         -- Theme listing/discovery with cached preview data
    AppCommand.swift           -- Command enum: IDs, titles, shortcut hints (see context/commands.md)
    Agents/                    -- Pluggable agent CLI detection (Claude, Gemini, Codex)
      AgentPresence.swift        -- Enum: thinking | idle | needsAttention
      AgentTitleDetector.swift   -- Protocol + AgentTitleDetection registry
      ClaudeTitleParser.swift    -- Claude Code: Braille spinner + idle glyphs
      GeminiTitleParser.swift    -- Gemini CLI: glyphs incl. needsAttention
      CodexTitleParser.swift     -- OpenAI Codex CLI: Braille spinner (no idle glyph)
    ConfigFile.swift           -- Observable key-value config file store (persisted to app support)
    GitWorktreeManager.swift   -- Git branch references and worktree detection per pane
    PaneEventHandler.swift     -- Pane event callbacks (attention, bell, thinking, title, pwd)
    SoundManager.swift         -- Sound trigger playback management
  Hootty/
    HoottyApp.swift            -- @main entry, initializes GhosttyApp
    CommandRegistry.swift      -- Maps AppCommand -> actions, generates palette entries
    HoottyBundle.swift         -- shared SPM resource bundle resolver (use for all bundled resources)
    CrashHandler.swift         -- Crash log writer (~/Library/Logs/Hootty/)
    Log.swift                  -- os.Logger wrapper (subsystem: com.soel.hootty)
    SafeSubscript.swift        -- Safe array subscript extension (returns nil on out-of-bounds)
    Views/
      ContentView.swift             -- Main layout: workspaces (sidebar + detail) vs templates view
      WorkspaceSidebar.swift        -- Workspace list with status indicators
      WorkspaceRow.swift            -- Workspace row with drag-and-drop
      SidebarPaneRow.swift          -- Pane row with status dot and layout thumbnail
      BranchSectionHeader.swift     -- Branch/worktree section header
      SidebarTreeLines.swift        -- Shared tree connector primitives (TreeLayout, TreeLinesBackground)
      PaneGroupTabBar.swift         -- Tab strip within a pane group region
      PaneGroupView.swift           -- Per-region pane group container (tab bar + split content)
      SplitView.swift               -- Recursive SplitNodeView rendering split panes with dividers
      TerminalPaneView.swift        -- NSViewRepresentable wrapping TerminalSurfaceView per Pane
      AnimatedBorderModifier.swift  -- Animated gradient border for attention state
      BarIconButton.swift           -- Reusable square icon button/menu for horizontal bars
      CapsulePickerView.swift       -- Reusable capsule segmented control (titlebar, sidebar)
      SearchModalView.swift         -- Reusable search modal container (palette, theme picker)
      CommandPaletteView.swift      -- Searchable command palette with keyboard navigation
      SplitLayoutThumbnail.swift    -- Canvas-drawn minimap of split layout
      StatusDotView.swift           -- Colored status dot indicator
      TemplatesView.swift           -- Templates feature UI
      ThemePickerView.swift         -- Theme selection modal with previews
      WindowAccessor.swift          -- NSWindow access from SwiftUI
    Terminal/
      GhosttyApp.swift              -- Singleton ghostty_app_t wrapper, runtime callbacks
      GhosttyApp+Actions.swift      -- Action callback handlers (split from GhosttyApp.swift)
      GhosttyConfigReader.swift     -- Reads resolved theme colors from ghostty config via C API
      TerminalSurfaceView.swift     -- NSView hosting ghostty_surface_t (Metal, keyboard/mouse input)
      TerminalSurfaceView+Keyboard.swift -- Keyboard event handling with IME and key modifiers
      ShellEscape.swift             -- Shell escaping utility for paths
Tests/
  HoottyCoreTests/                  -- unit and integration tests for model logic
Vendors/
  lib/libghostty.a                  -- pre-built libghostty static library
```

Uses [libghostty](https://github.com/ghostty-org/ghostty) for full terminal emulation (PTY, ANSI/VT parsing, Metal rendering, Kitty keyboard protocol).

## Data flow

- `ghostty_app_t` (singleton) - manages config and dispatches actions via callbacks
- `ghostty_surface_t` (per pane) - handles PTY, parsing, and Metal rendering internally
- `TerminalSurfaceView` (NSView) - hosts the surface, forwards keyboard/mouse events
- Action callbacks (title, pwd, exit) - update `Pane` model; `Workspace` aggregates; SwiftUI reacts
- Split panes: `Workspace.rootNode` is a `SplitNode` binary tree; each leaf holds a `Pane` with its own surface
- Commands: `AppCommand` enum -> `CommandRegistry` (maps to actions); menus, palette, and ghostty callbacks all dispatch through `commandRegistry.execute()`
