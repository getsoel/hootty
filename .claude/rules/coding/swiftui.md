---
globs: "**/*.swift"
---
Never use `@State` with an array of `@Observable` classes combined with `@Binding` in the App struct — causes swift_release EXC_BAD_ACCESS crash. Use an `@Observable` model class held by `@State` instead (e.g., `@State private var appModel = AppModel()`).

SPM executables need `NSApplication.shared.setActivationPolicy(.regular)` in the App's `init()` to get a proper window. This is a standard workaround for non-bundled SwiftUI apps.
