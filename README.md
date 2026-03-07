# Hootty

A macOS terminal emulator powered by [libghostty](https://github.com/ghostty-org/ghostty).

## Features

- **Split panes** -- horizontal and vertical splits with draggable dividers
- **Workspaces** -- organize terminal sessions into named workspaces
- **Catppuccin themes** -- built-in Catppuccin color schemes
- **Metal rendering** -- GPU-accelerated terminal rendering via libghostty
- **Kitty keyboard protocol** -- full modern keyboard input support

## Prerequisites

- macOS 14+
- Xcode (full install, not just Command Line Tools) -- provides Swift 5.10+ and `xcodebuild`
- [Zig](https://ziglang.org/) -- used to build libghostty from source
- [gettext](https://www.gnu.org/software/gettext/) -- provides `msgfmt`, needed by the ghostty build

### Installing Xcode

Install Xcode from the App Store or [developer.apple.com](https://developer.apple.com/xcode/). Then make sure it's the active developer directory:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -runFirstLaunch
xcodebuild -downloadComponent MetalToolchain
```

Verify with `xcodebuild -version` -- you need Xcode 15.3+ (Swift 5.10). The Metal toolchain is required to compile ghostty's Metal shaders.

### Installing Zig and gettext

```sh
brew install zig gettext
```

Or download Zig from [ziglang.org](https://ziglang.org/download/).

## Quick Start

```sh
git clone --recurse-submodules https://github.com/soel/hootty.git
cd hootty
make setup   # init submodule, build libghostty (cached), configure git hooks
make build   # compile (requires xcodebuild)
make run     # build and launch
```

`make setup` builds libghostty from the ghostty submodule and caches the result at `~/.cache/hootty/ghosttykit/<sha>/`. Subsequent runs reuse the cache unless the submodule is updated.

## Architecture

SwiftUI app with a vendored libghostty static library handling terminal emulation (PTY, VT parsing) and Metal rendering. See `CLAUDE.md` for detailed architecture notes.

## License

[MIT](LICENSE)
