# libghostty integration

Use when: working in Sources/Hootty/Terminal/ or Sources/CGhostty/ (ghostty_surface_t / ghostty_app_t, callbacks, clipboard, key handling).

## Surface is monolithic

- `ghostty_surface_t` handles PTY, VT parsing, and Metal rendering internally. Never layer separate PTYProcess, TerminalEmulator, or Renderer abstractions on top.
- The NSView (`TerminalSurfaceView`) only forwards keyboard/mouse events and handles action callbacks (title, pwd, exit).

## App singleton

- `ghostty_app_t` is a singleton (`GhosttyApp.shared`). Create one per application, create surfaces within it.
- All ghostty API calls must happen on the main thread.

## Surface lifecycle

- Defer `ghostty_surface_new()` until `viewDidMoveToWindow()` - Metal context and display IDs aren't available in `init()`. Store config params and create lazily.
- Use `Unmanaged.passRetained` with a dedicated `SurfaceCallbackContext` class for surface userdata, never `passUnretained(self)`. The context holds a `weak var view` and explicit `retainedPointer()` / `release()` lifecycle tied to the surface.
- Free surfaces asynchronously in `deinit`: nil the reference immediately to prevent stale access, then `Task { @MainActor in ghostty_surface_free(surface) }` to avoid re-entrant callback crashes.

## Window / view lifecycle

- `viewDidChangeOcclusionState` is on `NSWindow`, not `NSView`. For occlusion tracking, observe `NSWindow.didChangeOcclusionStateNotification` on the view's window.

## Callbacks

- In ghostty runtime callbacks, copy C string data (`String(cString: ptr)`) synchronously before `DispatchQueue.main.async`. Ghostty may free the buffer before the async block runs, causing use-after-free.
- `ghostty_surface_complete_clipboard_request(surface, data, state, confirm)` - arg1 is `ghostty_surface_t`, arg3 is the opaque `state` from the callback. All params are `void*` typedefs so the compiler won't catch swaps.
- `close_surface_cb` receives app-level userdata (`ghostty_app_t` runtime userdata), not a `SurfaceCallbackContext`. To close a specific pane from a runtime callback, route through action callbacks (`GHOSTTY_ACTION_SHOW_CHILD_EXITED` -> `processDidExit`) or static helpers that accept pane IDs.

## Split API

- `ghostty_action_split_direction_e` constants: `GHOSTTY_SPLIT_DIRECTION_RIGHT`, `GHOSTTY_SPLIT_DIRECTION_DOWN`, `GHOSTTY_SPLIT_DIRECTION_LEFT`, `GHOSTTY_SPLIT_DIRECTION_UP`.
- For inherited surface config use `ghostty_surface_inherited_config(surface, GHOSTTY_SURFACE_CONTEXT_SPLIT)` - the second arg is `ghostty_surface_context_e`, not a split direction.

## Env var injection

- To inject env vars into a surface's PTY, use `env_vars` / `env_var_count` on `ghostty_surface_config_s`.
- Keys and values must be `strdup`'d C strings (ghostty reads them during `ghostty_surface_new`). Always `defer { free/deallocate }` immediately after allocation - never rely on manual free at end of scope, as future edits may add early returns.

## Keyboard

- In `performKeyEquivalent`, only return `true` for keys that genuinely need claiming: Escape (`0x35`, prevents window close), Ctrl+Return (`0x24`, prevents context menu), Ctrl+/ (`0x2C`, prevents beep), and consumed ghostty bindings.
- Never blanket-claim all non-command keys - per Apple docs, `keyUp:` events are not delivered for key equivalents, so returning `true` suppresses RELEASE events and breaks Kitty keyboard protocol (causes garbled display on arrow keys, broken backspace/delete).

## Agent presence signals

Three independent channels feed `PaneEventHandler`, in decreasing authority:

1. **hootty OSC 9 protocol** (`hootty:presence:`, `hootty:resume:`, …) — the
   opt-in contract, driven by the hook scripts the wrappers inject. The only
   channel that can express "blocked on a permission prompt".
2. **Terminal titles** — `AgentTitleDetection` matches a leading glyph.
   Claude Code 2.x spins `◐◑` (U+25D0–U+25D3) and parks on `✳`; older versions
   and Codex spin Braille. This is the fallback for un-wrapped agents, so keep
   old glyphs when adding new ones.
3. **OSC 9;4 progress reports** — Claude Code brackets each turn with
   indeterminate/remove. Only refines panes that are *already* agent panes:
   ordinary tools report progress too, so this must never promote a plain
   terminal.

Agent CLIs change their glyphs between releases. When presence stops working,
capture a real session through a PTY and log its OSC sequences before touching
the parsers — that is what distinguishes a glyph change from a dead channel.

## Agent hook channel

Agent CLIs report their state to Hootty by writing OSC sequences that ghostty's
parser picks up (`hootty:presence:`, `hootty:resume:`, `hootty:session:`, and
OSC 7 for cwd). Two things break the obvious implementation:

- **Hook stdout is not a channel.** Claude Code, Gemini and Codex all consume a
  hook's stdout as a structured response — for some events it is folded into the
  model's context. An OSC written to stdout leaks into the conversation and
  never reaches the parser.
- **`/dev/tty` is not a channel either.** Claude Code 2.x runs hook commands
  detached from the controlling terminal: `tty` reports "not a tty" and opening
  `/dev/tty` fails with ENXIO, so the write is silently dropped.

Hooks therefore address the pane's PTY *by path* — writing to the slave device
reaches ghostty exactly like stdout would. `bin/hootty-tty.sh` resolves it
(parent process's tty, then `HOOTTY_TTY`, then `/dev/tty`); every hook script
sources it and writes to `$HOOTTY_OSC_TTY`.

## Wrapper PATH ordering

`applyHoottyEnvVars` prepends `Resources/bin` to PATH, but that only holds until
the user's rc files run — one `export PATH="$HOME/.local/bin:$PATH"` in
`.zshenv` puts Claude Code's native install ahead of Hootty's `claude` wrapper
and silently disables every hook it injects.

`Resources/shell-integration/hootty/` re-asserts the directory's position on
each prompt (and exports `HOOTTY_TTY`). It is sourced by one added line in each
vendored ghostty integration file — grep `# Hootty:` there before syncing
upstream. Elvish and nushell are not covered.
