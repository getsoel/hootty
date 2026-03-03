# Klaude

macOS PTY terminal emulator — SwiftUI app (macOS 14+) that spawns shell processes in a PTY and renders ANSI-colored output.

## Commands
- `swift build`: compile
- `swift run Klaude`: launch app (window appears with zsh session)

## Architecture
```
Sources/Klaude/
  KlaudeApp.swift          -- @main entry
  Models/
    AppModel.swift          -- @Observable app state, session management
    Session.swift           -- @Observable: id, name, isRunning, shell, workingDirectory
    TerminalTheme.swift     -- Catppuccin themes + SwiftTerm color conversion
    ThemeManager.swift      -- Persisted theme selection
  Views/
    ContentView.swift       -- NavigationSplitView: sidebar + terminal
    SessionSidebar.swift    -- Session list with status indicators
    TerminalView.swift      -- NSViewRepresentable wrapping SwiftTerm LocalProcessTerminalView
```

Depends on [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) for full xterm-compatible terminal emulation (PTY, ANSI parsing, rendering, keyboard input).
