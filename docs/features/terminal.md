# Terminal

Hootty's terminal emulation is powered by [libghostty](https://github.com/ghostty-org/ghostty), providing a fast, fully-featured terminal experience with GPU-accelerated rendering.

## Features

### Rendering

- **Metal GPU acceleration** — terminal content is rendered directly on the GPU for smooth scrolling and high frame rates.
- **Retina/HiDPI support** — automatically detects display scale and renders at native resolution. Adjusts when the window moves between displays with different scale factors.
- **Occlusion-aware** — rendering pauses when the terminal is fully hidden or minimized, saving GPU and CPU resources.

### Keyboard input

- Full keyboard input forwarding to the shell, including modifier combinations.
- **Input Method Editor (IME)** support for composing characters (CJK, accented characters, etc.). The IME candidate window appears at the cursor position.
- **Kitty keyboard protocol** support for enhanced key reporting in compatible applications.
- Escape is always captured by the terminal — it won't close the window or trigger other system actions.

### Mouse input

- Click, drag, and scroll events are forwarded to the terminal.
- Mouse tracking modes are supported for applications that use them (e.g., vim, tmux).
- Scroll wheel events work with both trackpad and mouse, including momentum scrolling.

### Clipboard

- Standard macOS copy and paste (`Cmd+C` / `Cmd+V`) through the system clipboard.
- Applications can read from and write to the clipboard via terminal escape sequences.

### Cursor

The terminal cursor shape updates based on the application's request:
- **I-beam** — default text editing cursor.
- **Pointer** — for clickable elements.
- **Arrow** — default system cursor.

The cursor auto-hides during typing and reappears on mouse movement.

### Working directory tracking

The terminal tracks the shell's current working directory via escape sequences (OSC 7). This is used to:
- Set the default directory for new tabs and splits.
- Display the current path in the pane name.

### Process state

Each pane tracks whether its shell process is running or has exited:
- **Running** — shown with a green status indicator in the tab bar.
- **Exited** — the pane can be closed or remains for output review.

When a process exits, the pane is automatically closed.

### Environment variables

Hootty injects environment variables into each terminal session:
- `HOOTTY_PANE_ID` — the unique identifier for the pane (used by integrations like Claude Code hooks).
- `PATH` — prepended with Hootty's bundled scripts directory, enabling transparent command wrapping.
