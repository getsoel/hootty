After modifying any file in Sources/KlaudeCore/, run `swift test` to verify model logic.
When adding new model logic, add corresponding tests in Tests/KlaudeCoreTests/.

KlaudeCore is a UI-free library target. Never add `import SwiftUI` to files in Sources/KlaudeCore/ — it must stay testable without UI dependencies.

Use `init()` on Swift Testing `@Suite` structs for shared setup (e.g., UserDefaults cleanup). The struct re-initializes per test automatically.

`AppModel()` with default `WorkspaceStore()` loads persisted data from disk, polluting test assertions. Always use `AppModel(workspaceStore: WorkspaceStore(fileURL: tempURL))` with a unique temp file per test.
