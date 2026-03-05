# Klaude

macOS terminal emulator — SwiftUI app (macOS 14+) powered by libghostty for terminal emulation and Metal rendering.

## Commands
- `swift build`: compile
- `swift test`: run unit tests (KlaudeCoreTests)
- `swift run Klaude`: launch app (window appears with zsh session)

After modifying Swift source files, verify `swift build` succeeds.

## Architecture
```
Sources/
  CGhostty/
    include/ghostty.h          -- vendored libghostty C headers
    include/module.modulemap   -- SPM module map
    shims.c                    -- placeholder for SPM
  KlaudeCore/                  -- testable library target (no UI dependencies)
    AppModel.swift             -- @Observable app state, workspace/tab management
    Workspace.swift            -- @Observable: id, name, tabs[], selectedTabID
    Tab.swift                  -- @Observable: id, name, isRunning, shell, workingDirectory
    TerminalTheme.swift        -- Catppuccin themes (palette definitions)
    ThemeManager.swift         -- Persisted theme selection
  Klaude/
    KlaudeApp.swift            -- @main entry, initializes GhosttyApp
    Views/
      ContentView.swift        -- HStack: sidebar + tab bar + terminal
      WorkspaceSidebar.swift   -- Workspace list with status indicators
      TabBar.swift             -- Tab strip within a workspace
      TerminalView.swift       -- NSViewRepresentable wrapping TerminalSurfaceView
    Terminal/
      GhosttyApp.swift         -- Singleton ghostty_app_t wrapper, runtime callbacks
      TerminalSurfaceView.swift -- NSView hosting ghostty_surface_t (Metal rendering, keyboard/mouse input)
Tests/
  KlaudeCoreTests/             -- unit tests for model logic
Vendors/
  lib/libghostty.a             -- pre-built libghostty static library
```

Uses [libghostty](https://github.com/ghostty-org/ghostty) for full terminal emulation (PTY, ANSI/VT parsing, Metal rendering, Kitty keyboard protocol).

## Rebuilding libghostty
From the ghostty repo (not this repo). Default `zig build -Dapp-runtime=none` fails on macOS.
```
cd /path/to/ghostty
zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dxcframework-target=native
cp macos/GhosttyKit.xcframework/macos-arm64/libghostty-fat.a /path/to/klaude/Vendors/lib/libghostty.a
cp -R macos/GhosttyKit.xcframework/macos-arm64/Headers/* /path/to/klaude/Sources/CGhostty/include/
```

### Data flow
- ghostty_app_t (singleton) → manages config and dispatches actions via callbacks
- ghostty_surface_t (per session) → handles PTY, parsing, and Metal rendering internally
- TerminalSurfaceView (NSView) → hosts the surface, forwards keyboard/mouse events
- Action callbacks (title, pwd, exit) → update Tab model → SwiftUI reacts

## Debugging

All runtime logging uses Apple's Unified Logging (`os.Logger`) with subsystem `com.soel.klaude`.

```bash
# Tail live logs while app runs (in a separate terminal):
log stream --predicate 'subsystem == "com.soel.klaude"' --level debug

# View recent logs after a crash:
log show --predicate 'subsystem == "com.soel.klaude"' --last 5m --style compact

# Filter by category (ghostty, surface, lifecycle, crash):
log show --predicate 'subsystem == "com.soel.klaude" AND category == "ghostty"' --last 5m

# Check crash log:
cat ~/Library/Logs/Klaude/crash.log

# Run with stderr visible:
swift run Klaude 2>&1 | tee /tmp/klaude-stderr.log
```
