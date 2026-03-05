---
globs: Sources/Klaude/Terminal/**/*.swift
---
ghostty_surface_t is monolithic — it handles PTY, VT parsing, and Metal rendering internally. Never layer separate PTYProcess, TerminalEmulator, or Renderer abstractions on top. The NSView (TerminalSurfaceView) only forwards keyboard/mouse events and handles action callbacks (title, pwd, exit).

ghostty_app_t is a singleton (GhosttyApp.shared). Create one per application, create surfaces within it. All ghostty API calls must happen on the main thread.

Defer `ghostty_surface_new()` until `viewDidMoveToWindow()` — Metal context and display IDs aren't available in `init()`. Store config params and create lazily.

Use `Unmanaged.passRetained` with a dedicated `SurfaceCallbackContext` class for surface userdata, never `passUnretained(self)`. The context holds a `weak var view` and explicit `retainedPointer()`/`release()` lifecycle tied to the surface.

Free surfaces asynchronously in `deinit`: nil the reference immediately to prevent stale access, then `Task { @MainActor in ghostty_surface_free(surface) }` to avoid re-entrant callback crashes.

`viewDidChangeOcclusionState` is on NSWindow, not NSView. For occlusion tracking, observe `NSWindow.didChangeOcclusionStateNotification` on the view's window.
