# Hootty

A macOS terminal emulator powered by [libghostty](https://github.com/ghostty-org/ghostty).

## Features

- **Split panes** — horizontal and vertical splits with draggable dividers
- **Workspaces** — organize terminal sessions into named workspaces
- **Catppuccin themes** — built-in Catppuccin color schemes
- **Metal rendering** — GPU-accelerated terminal rendering via libghostty
- **Kitty keyboard protocol** — full modern keyboard input support

## Prerequisites

- macOS 14+
- Swift 5.10+

## Quick Start

```sh
git clone https://github.com/soel/hootty.git
cd hootty
make setup   # configure git hooks
make run     # build and launch
```

## Architecture

SwiftUI app with a vendored libghostty static library handling terminal emulation (PTY, VT parsing) and Metal rendering. See `CLAUDE.md` for detailed architecture notes.

## License

[MIT](LICENSE)
