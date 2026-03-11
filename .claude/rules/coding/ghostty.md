---
globs: Sources/Hootty/Terminal/**/*.swift, Sources/CGhostty/**
---
ghostty_surface_t is monolithic — it handles PTY, VT parsing, and Metal rendering internally. Never layer separate PTYProcess, TerminalEmulator, or Renderer abstractions on top. The NSView (TerminalSurfaceView) only forwards keyboard/mouse events and handles action callbacks (title, pwd, exit).

ghostty_app_t is a singleton (GhosttyApp.shared). Create one per application, create surfaces within it. All ghostty API calls must happen on the main thread.

Defer `ghostty_surface_new()` until `viewDidMoveToWindow()` — Metal context and display IDs aren't available in `init()`. Store config params and create lazily.

Use `Unmanaged.passRetained` with a dedicated `SurfaceCallbackContext` class for surface userdata, never `passUnretained(self)`. The context holds a `weak var view` and explicit `retainedPointer()`/`release()` lifecycle tied to the surface.

Free surfaces asynchronously in `deinit`: nil the reference immediately to prevent stale access, then `Task { @MainActor in ghostty_surface_free(surface) }` to avoid re-entrant callback crashes.

`viewDidChangeOcclusionState` is on NSWindow, not NSView. For occlusion tracking, observe `NSWindow.didChangeOcclusionStateNotification` on the view's window.

`ghostty_surface_complete_clipboard_request(surface, data, state, confirm)` — arg1 is `ghostty_surface_t`, arg3 is the opaque `state` from the callback. All params are `void*` typedefs so the compiler won't catch swaps.

In ghostty runtime callbacks, copy C string data (`String(cString: ptr)`) synchronously before `DispatchQueue.main.async`. Ghostty may free the buffer before the async block runs, causing use-after-free.

Split API types: `ghostty_action_split_direction_e` with constants `GHOSTTY_SPLIT_DIRECTION_RIGHT`, `GHOSTTY_SPLIT_DIRECTION_DOWN`, `GHOSTTY_SPLIT_DIRECTION_LEFT`, `GHOSTTY_SPLIT_DIRECTION_UP`. For inherited surface config use `ghostty_surface_inherited_config(surface, GHOSTTY_SURFACE_CONTEXT_SPLIT)` — the second arg is `ghostty_surface_context_e`, not a split direction.

In `performKeyEquivalent`, only return `true` for keys that genuinely need claiming: Escape (`0x35`, prevents window close), Ctrl+Return (`0x24`, prevents context menu), Ctrl+/ (`0x2C`, prevents beep), and consumed ghostty bindings. Never blanket-claim all non-command keys — per Apple docs, `keyUp:` events are not delivered for key equivalents, so returning `true` suppresses RELEASE events and breaks Kitty keyboard protocol (causes garbled display on arrow keys, broken backspace/delete).

`close_surface_cb` receives app-level userdata (`ghostty_app_t` runtime userdata), not a `SurfaceCallbackContext`. To close a specific pane from a runtime callback, route through action callbacks (`GHOSTTY_ACTION_SHOW_CHILD_EXITED` → `processDidExit`) or static helpers that accept pane IDs.

To inject env vars into a surface's PTY, use `env_vars`/`env_var_count` on `ghostty_surface_config_s`. Keys and values must be `strdup`'d C strings (ghostty reads them during `ghostty_surface_new`). Always `defer { free/deallocate }` immediately after allocation — never rely on manual free at end of scope, as future edits may add early returns.
