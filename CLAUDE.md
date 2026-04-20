# Hootty

macOS terminal emulator - SwiftUI app (macOS 14+) powered by libghostty for terminal emulation and Metal rendering.

## Setup

After cloning, run `make setup` to configure git hooks (pre-commit runs the build).

## Commands

- `make build` - compile (xcodebuild, required for xcassets)
- `make run` - build + launch app
- `make debug` - build + launch with log streaming
- `swift test` - run HoottyCoreTests
- `swift test --filter <Name>` - single test
- `make format` / `make format-check` / `make lint`

## Architecture

- `Sources/CGhostty/` - vendored libghostty C headers + SPM module map
- `Sources/HoottyCore/` - UI-free model layer: AppModel, Workspace, SplitNode, Pane, themes, agents
- `Sources/Hootty/` - SwiftUI app, views, terminal surface wrapper, command registry
- `Tests/HoottyCoreTests/` - model-layer tests
- `Vendors/lib/libghostty.a` - pre-built static library

Full tree and data flow: `context/architecture.md`.

## Naming: Tab vs Pane vs Group

- **Tab** - UI item in the tab bar. Use for "Rename Tab", "Close Tab".
- **Pane** - underlying terminal session. Use for "Close Pane", "Split Pane".
- **Group** / **PaneGroup** - container of panes shown as a region with its own tab bar. Use for "Close Group".

## Before Finishing

- `make build` succeeds
- `swift test` passes (ignore signal 10 exit - see CLAUDE.local.md)
- `make format-check` passes
- `make lint` passes
- Only task-relevant files changed

@context/index.md
