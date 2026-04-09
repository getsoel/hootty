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
- `make format`: auto-format Swift sources with SwiftFormat
- `make format-check`: check formatting without modifying files
- `make lint`: run SwiftLint on Swift sources

## Architecture
```
Sources/
  CGhostty/
    include/ghostty.h          -- vendored libghostty C headers
    include/module.modulemap   -- SPM module map
    shims.c                    -- placeholder for SPM
  HoottyCore/                -- testable library target (no UI dependencies)
    AppModel.swift             -- @Observable app state, workspace/theme/sound management
    Workspace.swift            -- @Observable: id, name, rootNode (SplitNode), focusedPaneID
    Pane.swift                 -- @Observable: id, name, isRunning, shell, workingDirectory
    SplitNode.swift            -- @Observable binary tree: leaf(Pane) | split(direction, first, second)
    WorkspaceStore.swift       -- Persistence: save/load workspaces to disk
    DesignTokens.swift         -- Semantic color/spacing tokens (see docs/DESIGN.md)
    TerminalTheme.swift        -- Catppuccin themes (palette definitions)
    ThemeManager.swift         -- Persisted theme selection
    ThemeCatalog.swift         -- Theme listing/discovery with cached preview data
    AppCommand.swift           -- Command enum: IDs, titles, shortcut hints (see docs/COMMANDS.md)
    Agents/                    -- Pluggable agent CLI detection (Claude, Gemini, Codex)
      AgentPresence.swift        -- Enum: thinking | idle | needsAttention
      AgentTitleDetector.swift   -- Protocol + AgentTitleDetection registry
      ClaudeTitleParser.swift    -- Claude Code: Braille spinner + ✳/* idle glyphs
      GeminiTitleParser.swift    -- Gemini CLI: ◇✦⏲✋ glyphs incl. needsAttention
      CodexTitleParser.swift     -- OpenAI Codex CLI: Braille spinner (no idle glyph)
    ConfigFile.swift           -- Observable key-value config file store (persisted to app support)
    GitWorktreeManager.swift   -- Git branch references and worktree detection per pane
    PaneEventHandler.swift     -- Pane event callbacks (attention, bell, thinking, title, pwd)
    SoundManager.swift         -- Sound trigger playback management
  Hootty/
    HoottyApp.swift          -- @main entry, initializes GhosttyApp
    CommandRegistry.swift      -- Maps AppCommand → actions, generates palette entries
    HoottyBundle.swift         -- shared SPM resource bundle resolver (use for all bundled resources)
    CrashHandler.swift         -- Crash log writer (~/Library/Logs/Hootty/)
    Log.swift                  -- os.Logger wrapper (subsystem: com.soel.hootty)
    SafeSubscript.swift        -- Safe array subscript extension (returns nil on out-of-bounds)
    Views/
      ContentView.swift        -- Main layout: switches between workspaces (sidebar + detail) and templates view
      WorkspaceSidebar.swift   -- Workspace list with status indicators
      WorkspaceRow.swift       -- Extracted workspace row with drag-and-drop
      SidebarPaneRow.swift     -- Extracted pane row with status dot and layout thumbnail
      BranchSectionHeader.swift -- Extracted branch/worktree section header
      SidebarTreeLines.swift   -- Shared tree connector primitives (TreeLayout, TreeLinesBackground)
      PaneGroupTabBar.swift     -- Tab strip within a pane group region
      PaneGroupView.swift      -- Per-region pane group container (tab bar + split content)
      SplitView.swift          -- Recursive SplitNodeView rendering split panes with dividers
      TerminalPaneView.swift   -- NSViewRepresentable wrapping TerminalSurfaceView per Pane
      AnimatedBorderModifier.swift -- Animated gradient border for attention state
      BarIconButton.swift      -- Reusable square icon button/menu for horizontal bars
      CapsulePickerView.swift  -- Reusable capsule segmented control (used by titlebar, sidebar)
      SearchModalView.swift    -- Reusable search modal container (used by command palette, theme picker)
      CommandPaletteView.swift -- Searchable command palette with keyboard navigation
      SplitLayoutThumbnail.swift -- Canvas-drawn minimap of split layout
      StatusDotView.swift      -- Colored status dot indicator
      TemplatesView.swift      -- Templates feature UI
      ThemePickerView.swift    -- Theme selection modal with previews
      WindowAccessor.swift     -- NSWindow access from SwiftUI
    Terminal/
      GhosttyApp.swift         -- Singleton ghostty_app_t wrapper, runtime callbacks
      GhosttyApp+Actions.swift -- Action callback handlers (split from GhosttyApp.swift)
      GhosttyConfigReader.swift -- Reads resolved theme colors from ghostty config via C API
      TerminalSurfaceView.swift -- NSView hosting ghostty_surface_t (Metal rendering, keyboard/mouse input)
      TerminalSurfaceView+Keyboard.swift -- Keyboard event handling with IME and key modifiers
      ShellEscape.swift        -- Shell escaping utility for paths
Tests/
  HoottyCoreTests/           -- unit tests for model logic
Vendors/
  lib/libghostty.a             -- pre-built libghostty static library
```

Uses [libghostty](https://github.com/ghostty-org/ghostty) for full terminal emulation (PTY, ANSI/VT parsing, Metal rendering, Kitty keyboard protocol).

### Data flow
- ghostty_app_t (singleton) → manages config and dispatches actions via callbacks
- ghostty_surface_t (per pane) → handles PTY, parsing, and Metal rendering internally
- TerminalSurfaceView (NSView) → hosts the surface, forwards keyboard/mouse events
- Action callbacks (title, pwd, exit) → update Pane model → Workspace aggregates → SwiftUI reacts
- Split panes: Workspace.rootNode is a SplitNode binary tree; each leaf holds a Pane with its own surface
- Commands: AppCommand enum → CommandRegistry (maps to actions) → menus, palette, ghostty callbacks all dispatch through `commandRegistry.execute()`

### Deep-dive docs (read on demand)
- `docs/COMMANDS.md` — read when adding commands, modifying keyboard shortcuts, or working on the command palette
- `docs/DESIGN.md` — read when creating or modifying UI components, working with design tokens or theme colors
- `docs/DEBUGGING.md` — read when investigating crashes or runtime issues
- `docs/HOOKS.md` — read when modifying the wrapper script, env var injection, or attention indicators
- `docs/REBUILDING.md` — read when updating or rebuilding libghostty
- `docs/CONFIG.md` — read when working on the config file system or adding new settings
- `docs/RULES.md` — read when adding new `.claude/rules/` files or modifying progressive disclosure structure

### Naming: Tab vs Pane vs Group
- **Tab**: UI presentation concept — items in the tab bar. Use in tab bar context: "Rename Tab", "Close Tab"
- **Pane**: The underlying terminal session. Use in sidebar tree and split contexts: "Close Pane", "Split Pane"
- **Group** / **PaneGroup**: Container of panes shown as a region with its own tab bar. Use in sidebar: "Close Group"

## Before Finishing
- `make build` succeeds
- `swift test` passes (ignore signal 10 exit — see CLAUDE.local.md)
- `make format-check` passes
- `make lint` passes
- Only task-relevant files changed
