---
globs: Sources/Klaude/Terminal/**/*.swift
---
ghostty_surface_t is monolithic — it handles PTY, VT parsing, and Metal rendering internally. Never layer separate PTYProcess, TerminalEmulator, or Renderer abstractions on top. The NSView (TerminalSurfaceView) only forwards keyboard/mouse events and handles action callbacks (title, pwd, exit).

ghostty_app_t is a singleton (GhosttyApp.shared). Create one per application, create surfaces within it. All ghostty API calls must happen on the main thread.
