# Modules

## Overview

Modules are optional experimental feature areas that can be enabled/disabled via the config file or command palette. Each module adds UI elements (bars, views, sidebar controls), model logic, and watcher/callback integration. Modules default to disabled.

### Design Principles

1. **Config-driven** — Each module has a `module-<name>` key in ConfigFile. No compile-time flags.
2. **Bundled as ModuleFlags** — View hierarchy threads a single `ModuleFlags` struct, not individual booleans. Adding a module means adding one field.
3. **Guard at boundaries** — Disable modules at the outermost guard point (view, callback, watcher), not deep in model code.
4. **Model stays unconditional** — Model types (PipelineModel, MacroRunner) exist regardless of flags. Guards only control UI and side-effect entry points.

## Architecture

### ModuleFlags Struct

`Sources/HoottyCore/ModuleFlags.swift` — plain value type bundling all module toggles:

```swift
public struct ModuleFlags: Equatable, Sendable {
    public let pipelines: Bool
    public let macros: Bool
    public init(pipelines: Bool = false, macros: Bool = false)
}
```

- `Equatable` + `Sendable` for cheap SwiftUI diffing
- Computed from `AppModel.moduleFlags` (bridges ConfigFile values)
- Threaded through view hierarchy: `ContentView` → `SplitNodeView` → `PaneContentView`, and `ContentView` → `WorkspaceSidebar`

### Config Keys

| Module | Config key | Default |
|--------|-----------|---------|
| Pipelines | `hootty-module-pipelines` | disabled (key absent or not "true") |
| Macros | `hootty-module-macros` | disabled (key absent or not "true") |

Toggle properties on `AppModel`: `pipelinesEnabled`, `macrosEnabled` (read/write to ConfigFile).

### Guard Point Taxonomy

| Type | Where | Example |
|------|-------|---------|
| **View guard** | SwiftUI `if` around UI elements | `if moduleFlags.pipelines { PipelineBarView(...) }` |
| **Callback guard** | HoottyApp action handlers | `guard appModel.macrosEnabled else { return }` |
| **Watcher guard** | Watcher bootstrap | `if appModel.pipelinesEnabled { pipelineWatcher.setOnChange ... }` |
| **Command guard** | Command registration | `if appModel.macrosEnabled { commandRegistry.register(.runMacro) ... }` |

Views receive `moduleFlags` (struct). HoottyApp and callbacks access `appModel.pipelinesEnabled`/`macrosEnabled` directly since they have model access.

## Adding a New Module — Checklist

1. **Config key**: Add `hootty-module-<name>` read/write property on `AppModel` using `configFile.defaultFalseBool("hootty-module-<name>")`
2. **ModuleFlags field**: Add `public let <name>: Bool` to `ModuleFlags`, update `init` with default `false`
3. **AppModel.moduleFlags**: Include new field in the computed property
4. **Model types**: Create module's model/state types in `Sources/HoottyCore/` (no feature flag checks)
5. **View guards**: Add `if moduleFlags.<name>` around module UI in `PaneContentView`, `WorkspaceSidebar`, etc.
6. **HoottyApp guards**: Gate command registration, callback handlers, and watcher setup behind `appModel.<name>Enabled`
7. **onChange handler**: In `ContentView`, add `.onChange(of: appModel.<name>Enabled)` to clean up UI state when disabled
8. **Commands**: Add any module-specific commands to `AppCommand` and register in `HoottyApp`
9. **Tests**: Add test in `AppModelTests` verifying `moduleFlags` includes the new field
10. **Architecture tree**: Add model files to `CLAUDE.md` architecture section
11. **This doc**: Add module entry under "Existing Modules" below
12. **Rules**: Update `.claude/rules/business/modules.md` if new patterns emerge

## Existing Modules

### Pipelines

**Purpose**: Kanban-style pipeline boards where jobs progress through stages, with per-pane claim bars.

**Config key**: `hootty-module-pipelines`

**HoottyCore files**:
- `PipelineModel.swift` — `@Observable` claim/board state per pane/repo
- `PipelineReader.swift` — Reads pipeline config and state from `.hootty/pipeline/`
- `PipelineState.swift` — Data structures (stages, config, jobs, claims)
- `PipelineWriter.swift` — Writes job files and `.state.json` mutations

**View files**:
- `PipelineBarView.swift` — Per-pane claim bar with stage progress dots
- `PipelineBoardView.swift` — Kanban board grouped by pipeline stages
- `PipelineBoardFactory.swift` — AppModel extension constructing board view

**Guard points**:
- `PaneContentView` (line ~40): `if moduleFlags.pipelines` around `PipelineBarView`
- `WorkspaceSidebar` (line ~144): `if moduleFlags.pipelines` around sidebar tab picker
- `ContentView`: titlebar mode picker, main content switch, detail view switch, `onSwitchToBoard`/`onPipelineRefresh` closures
- `HoottyApp`: pipeline watcher bootstrap, pwd-change watcher registration

**Data flow**: `PipelineWatcher` monitors `.hootty/pipeline/.state.json` → `PipelineModel` updates → `PipelineBarView`/`PipelineBoardView` react. See `docs/specs/PIPELINE_SPEC.md` for full spec.

### Macros

**Purpose**: Multi-step Claude Code automation — define sequences of prompts that execute in order on a pane.

**Config key**: `hootty-module-macros`

**HoottyCore files**:
- `MacroStore.swift` — Macro template definitions and persistence
- `MacroRunner.swift` — `@Observable` execution state (active macros, step progress)

**View files**:
- `MacroBarView.swift` — Per-pane progress bar showing current macro step

**Guard points**:
- `PaneContentView` (line ~67): `if moduleFlags.macros` around `MacroBarView`
- `HoottyApp`: `runMacro` command registration, `onMacroStepDone` callback handler

**Data flow**: `MacroStore` provides templates → `MacroRunner` tracks per-pane execution → `GhosttyApp.onMacroStepDone` callback advances steps → `MacroBarView` displays progress.
