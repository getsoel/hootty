# Module System — Spec

## Overview

Make Pipelines and Macros opt-in modules that users can enable/disable. A user who only wants sidebar + workspaces + worktrees + terminal gets a clean app with no pipeline/macro UI, commands, or file watchers.

### Design Principles

1. **Runtime toggle** — Modules are enabled/disabled via `ConfigFile` (persisted key-value store), not compile-time flags. No separate build targets or SPM conditionals.
2. **Zero cost when off** — Disabled modules contribute no UI, no file watchers, no commands, no model allocations.
3. **No model surgery** — `AppModel` keeps its current properties (`pipelineModel`, `macroStore`, `macroRunner`). The toggle controls whether the UI and side-effects use them, not whether they exist. This avoids Codable migration, optional-unwrapping sprawl, and test fixture changes.
4. **Minimal diff** — Guard at the boundary (views, callbacks, command registration), not deep inside model logic.

## Config Keys

Stored in `ConfigFile` (the existing `~/.config/Hootty/config` key-value file):

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `module-pipelines` | `"true"` / `"false"` | `"true"` | Enable pipeline UI, board view, pipeline bar, file watchers |
| `module-macros` | `"true"` / `"false"` | `"true"` | Enable macro commands, macro bar, step injection |

Default `"true"` preserves current behavior — existing users see no change.

## AppModel API

Add computed properties to `AppModel` that read from `ConfigFile`:

```swift
// AppModel.swift
public var pipelinesEnabled: Bool {
    get { configFile.get("module-pipelines") != "false" }
    set {
        configFile.set("module-pipelines", value: newValue ? nil : "false")
        configFile.save()
    }
}

public var macrosEnabled: Bool {
    get { configFile.get("module-macros") != "false" }
    set {
        configFile.set("module-macros", value: newValue ? nil : "false")
        configFile.save()
    }
}
```

Pattern matches the existing `showWorktreeActions` property.

Setting to `nil` (the "true" case) removes the key from config, so the default-true convention holds.

## Guard Points

Each integration point below gets a single guard on the relevant `*Enabled` flag. When disabled, the code path is skipped entirely — no UI rendered, no callbacks wired, no watchers started.

### Pipeline Guards

#### 1. Titlebar app mode picker (`ContentView.titleBar`)
**Current**: Always shows `[Workspaces | Pipelines]` capsule picker.
**Change**: Only show picker when `pipelinesEnabled`. When disabled, omit the picker entirely (just show "Workspaces" as static text or nothing — the titlebar still renders but without the mode switcher).

```swift
// ContentView.swift — appModePicker
@ViewBuilder
private var appModePicker: some View {
    if appModel.pipelinesEnabled {
        CapsulePickerView(
            options: [AppModel.AppMode.workspaces, .pipelines],
            selection: $appModel.appMode,
            tokens: tokens,
            label: { $0 == .workspaces ? "Workspaces" : "Pipelines" }
        )
    }
}
```

#### 2. Main content switch (`ContentView.mainContent`)
**Current**: Switches between `workspacesContent` and `PipelinesView`.
**Change**: When disabled, always show `workspacesContent`. Force `appMode = .workspaces` if it was somehow `.pipelines`.

```swift
@ViewBuilder
private var mainContent: some View {
    if appModel.pipelinesEnabled {
        switch appModel.appMode {
        case .workspaces: workspacesContent
        case .pipelines: PipelinesView(appModel: appModel, tokens: tokens)
        }
    } else {
        workspacesContent
    }
}
```

#### 3. Sidebar detail mode picker (`WorkspaceSidebar`)
**Current**: Shows `[Terminals | Board]` tab picker with `pipelineAttentionCount` badge.
**Change**: When disabled, hide the tab picker. Always show `Terminals` detail mode. The sidebar tree renders the same either way.

Pass `pipelinesEnabled` to `WorkspaceSidebar`. Guard the `SidebarTab` picker and force `detailMode = .terminals`.

```swift
// WorkspaceSidebar — add parameter
var pipelinesEnabled: Bool = true

// In sidebar header, wrap tab picker:
if pipelinesEnabled {
    // existing CapsulePickerView for Terminals/Board
}
```

#### 4. Detail view board mode (`ContentView.detailView`)
**Current**: Switches between `terminalsDetail` and `boardDetail`.
**Change**: When disabled, only render `terminalsDetail`.

```swift
@ViewBuilder
private var detailView: some View {
    if let workspace = selectedWorkspace {
        if appModel.pipelinesEnabled {
            switch appModel.detailMode {
            case .terminals: terminalsDetail(workspace: workspace)
            case .board: boardDetail(workspace: workspace)
            }
        } else {
            terminalsDetail(workspace: workspace)
        }
    } else { /* empty state */ }
}
```

#### 5. Pipeline bar in pane content (`PaneContentView`)
**Current**: Shows `PipelineBarView` when a pane has a claim.
**Change**: Skip the claim check entirely when disabled. The `pipelineModel` parameter stays (avoids cascading signature changes through `SplitNodeView`), but the view never reads from it.

```swift
// PaneContentView.swift — add parameter
var pipelinesEnabled: Bool = true

// In body:
if pipelinesEnabled, let claim = pipelineModel.claimInfo(for: pane.id) {
    PipelineBarView(...)
}
```

#### 6. Pipeline callbacks in `SplitNodeView`
**Current**: `onSwitchToBoard` and `onPipelineRefresh` closures threaded through.
**Change**: These are already optional (`((String?) -> Void)?`). Pass `nil` when disabled:

```swift
// ContentView.terminalsDetail
SplitNodeView(
    ...
    onSwitchToBoard: appModel.pipelinesEnabled ? { pipelineName in ... } : nil,
    onPipelineRefresh: appModel.pipelinesEnabled ? { repoRoot in ... } : nil
)
```

#### 7. Pipeline watcher bootstrap (`HoottyApp.onAppear`)
**Current**: Bootstraps `PipelineWatcher` for all repos with `.hootty/pipeline/`.
**Change**: Skip when disabled.

```swift
if appModel.pipelinesEnabled {
    pipelineWatcher.setOnChange { ... }
    for workspace in appModel.workspaces {
        // existing bootstrap loop
    }
}
```

#### 8. Pipeline watcher on pwd change (`HoottyApp.onPwdChanged`)
**Current**: Registers pipeline watcher when a pane navigates to a repo with pipelines.
**Change**: Guard with `appModel.pipelinesEnabled`.

```swift
if appModel.pipelinesEnabled,
   let (_, pane) = appModel.findPane(id: paneID),
   let repoRoot = pane.repoRoot,
   PipelineModel.hasPipeline(repoRoot: repoRoot),
   appModel.pipelineModel.registerRepoRoot(repoRoot) {
    pipelineWatcher.startWatching(repoRoot: repoRoot)
}
```

#### 9. Pipeline attention count (`ContentView.sidebar`)
**Current**: Passes `pipelineAttentionCount` to sidebar.
**Change**: Pass `0` when disabled.

```swift
pipelineAttentionCount: appModel.pipelinesEnabled ? currentPipelineAttentionCount : 0
```

### Macro Guards

#### 1. Macro commands (`HoottyApp.registerCommands`)
**Current**: Registers `.runMacro` and `.cancelMacro` commands.
**Change**: Skip registration when disabled. Commands won't appear in palette.

```swift
if appModel.macrosEnabled {
    commandRegistry.register(.runMacro) { ... }
    commandRegistry.register(.cancelMacro) { ... }
}
```

#### 2. Macro bar in pane content (`PaneContentView`)
**Current**: Shows `MacroBarView` when a pane has active macro progress.
**Change**: Skip when disabled.

```swift
var macrosEnabled: Bool = true

// In body:
if macrosEnabled, let progress = macroRunner.progress(paneID: pane.id) {
    MacroBarView(...)
}
```

#### 3. Macro step done callback (`HoottyApp.onMacroStepDone`)
**Current**: Advances macro when Claude finishes thinking.
**Change**: Guard with `macrosEnabled`.

```swift
GhosttyApp.shared.onMacroStepDone = { [appModel] paneID in
    guard appModel.macrosEnabled else { return }
    guard appModel.macroRunner.isActive(paneID: paneID) else { return }
    if let nextStep = appModel.macroRunner.stepCompleted(paneID: paneID) {
        Self.injectMacroStep(nextStep, paneID: paneID)
    }
}
```

#### 4. Macro cleanup on pane/workspace close
**Current**: Calls `macroRunner.remove(paneID:)` on close.
**Change**: Keep as-is. `remove` on an empty dictionary is a no-op. Guarding adds complexity for zero benefit.

#### 5. Macro commands in `AppCommand` enum
**Current**: `runMacro` and `cancelMacro` cases exist.
**Change**: Keep as-is. The enum cases are inert without registered handlers. They won't appear in the palette because `CommandRegistry` only lists registered commands.

## Settings UI

Add a "Modules" section to a future settings view (or expose via command palette commands for now):

### Immediate: Config file
Users can edit their config file (`Edit Configuration...` command) and add:

```
module-pipelines = false
module-macros = false
```

Changes take effect on next app launch (ConfigFile is read at init). For live toggle, add commands:

### Commands (optional, phase 2)
Add `AppCommand` cases:

```swift
case togglePipelines
case toggleMacros
```

These would flip the config value and trigger a UI refresh. Since `configFile` is `@Observable` and the computed properties read from it, SwiftUI will re-evaluate the guards automatically when the underlying config changes.

## What Stays Unchanged

| Component | Reason |
|-----------|--------|
| `AppModel` properties (`pipelineModel`, `macroStore`, `macroRunner`) | Lightweight empty objects when unused. Avoids optional sprawl. |
| `PipelineModel`, `MacroRunner`, `MacroStore` classes | Still compiled, just never exercised when disabled. |
| `PipelineKit` SPM dependency on `HoottyCore` | Removing it would require extracting YAML utils. Not worth the churn. |
| `Pane.claudeSessionID` | Used for Claude detection display name too, not pipeline-only. |
| `SplitNodeView` parameter list | `pipelineModel`/`macroRunner` params stay to avoid cascading signature changes. The view just won't read them when disabled. |
| `AppModel.DetailMode.board` / `AppModel.AppMode.pipelines` | Enum cases stay. Dead code when disabled, but harmless. |
| `PipelineWatcher` instance in `HoottyApp` | Stays as `@State`. Just never starts watching when disabled. |
| All test files | Tests exercise model logic directly, unaffected by UI-level guards. |

## Files Changed

| File | Changes |
|------|---------|
| `Sources/HoottyCore/AppModel.swift` | Add `pipelinesEnabled` and `macrosEnabled` computed properties (~10 lines) |
| `Sources/Hootty/Views/ContentView.swift` | Guard app mode picker, main content switch, detail view, pipeline callbacks, attention count |
| `Sources/Hootty/Views/WorkspaceSidebar.swift` | Add `pipelinesEnabled` param, guard tab picker |
| `Sources/Hootty/Views/PaneContentView.swift` | Add `pipelinesEnabled`/`macrosEnabled` params, guard bars |
| `Sources/Hootty/HoottyApp.swift` | Guard pipeline watcher bootstrap, pwd watcher, macro commands, macro step callback |

No new files. No deleted files. No SPM changes. No test changes.

## Migration & Rollout

1. **Defaults to enabled** — zero behavior change for existing users.
2. **No data migration** — config key absence = enabled. No version checks needed.
3. **Reversible** — delete the config key or set to `true` to re-enable.
4. **No cleanup on disable** — existing pipeline files on disk are untouched. Re-enabling picks them back up via the watchers.

## Out of Scope

- Compile-time feature flags or conditional compilation (`#if`)
- Separate SPM targets per module
- Extracting `PipelineKit` YAML utils into a separate package
- Module-level plugin architecture or dynamic loading
- Settings UI beyond config file editing (phase 2)
- Disabling worktree features (already has `showWorktreeActions` toggle, separate concern)
