---
globs: Sources/HoottyCore/**/*.swift, Tests/HoottyCoreTests/**/*.swift
---

After modifying any file in Sources/HoottyCore/, run `swift test` to verify model logic.
When adding new model logic, add corresponding tests in Tests/HoottyCoreTests/.

Prefer **integration tests** that exercise multi-step workflows across model objects (AppModel, Workspace, SplitNode, Pane, WorkspaceStore) — especially persist/restore round-trips. These catch the regressions that matter most. Add integration tests to `Tests/HoottyCoreTests/IntegrationTests.swift`, grouped by workflow in `@Suite` structs.

Use **unit tests** sparingly and specifically: to pin down bad behavior we've encountered before (regression guards), not to exhaustively cover every method. If a behavior is already validated by an integration test, don't duplicate it as a unit test.

HoottyCore is a UI-free library target. Never add `import SwiftUI` to files in Sources/HoottyCore/ — it must stay testable without UI dependencies.

Use `init()` on Swift Testing `@Suite` structs for shared setup (e.g., UserDefaults cleanup). The struct re-initializes per test automatically.

`AppModel()` with default `WorkspaceStore()` loads persisted data from disk, polluting test assertions. Always use `AppModel(workspaceStore: WorkspaceStore(fileURL: tempURL))` with a unique temp file per test.
