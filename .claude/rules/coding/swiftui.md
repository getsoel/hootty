---
globs: "**/*.swift"
---
Never use `@State` with an array of `@Observable` classes combined with `@Binding` in the App struct — causes swift_release EXC_BAD_ACCESS crash. Use an `@Observable` model class held by `@State` instead (e.g., `@State private var appModel = AppModel()`).

SPM executables need `NSApplication.shared.setActivationPolicy(.regular)` in the App's `init()` to get a proper window. This is a standard workaround for non-bundled SwiftUI apps.

`Array.remove(atOffsets:)` is a SwiftUI extension, not Foundation. In UI-free targets (KlaudeCore), use manual reverse iteration: `for index in offsets.reversed() { array.remove(at: index) }`.

On `@Observable` classes, never use computed properties that allocate objects (NSColor, NSFont, etc.) — they re-allocate on every access/render. Use `private(set) var` cached values updated in `didSet` instead.

`KlaudeCore.Tab` collides with `SwiftUI.Tab` (macOS 15+). In view code, qualify as `KlaudeCore.Tab` in function signatures to disambiguate.

When the Swift compiler reports "unable to type-check this expression in reasonable time", extract sub-views into private computed properties or helper functions to reduce body complexity.
