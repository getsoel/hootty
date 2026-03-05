---
globs: "**/*.swift"
---
Never use `@State` with an array of `@Observable` classes combined with `@Binding` in the App struct — causes swift_release EXC_BAD_ACCESS crash. Use an `@Observable` model class held by `@State` instead (e.g., `@State private var appModel = AppModel()`).

SPM executables need `NSApplication.shared.setActivationPolicy(.regular)` in the App's `init()` to get a proper window. This is a standard workaround for non-bundled SwiftUI apps.

`Array.remove(atOffsets:)` is a SwiftUI extension, not Foundation. In UI-free targets (KlaudeCore), use manual reverse iteration: `for index in offsets.reversed() { array.remove(at: index) }`.

On `@Observable` classes, never use computed properties that allocate objects (NSColor, NSFont, etc.) — they re-allocate on every access/render. Use `private(set) var` cached values updated in `didSet` instead.

`KlaudeCore.Tab` collides with `SwiftUI.Tab` (macOS 15+). In view code, qualify as `KlaudeCore.Tab` in function signatures to disambiguate.

When the Swift compiler reports "unable to type-check this expression in reasonable time", extract sub-views into private computed properties or helper functions to reduce body complexity.

For custom titlebars (traffic lights only, no chrome), use `.windowStyle(.hiddenTitleBar)` on the `WindowGroup`. Do not manually set `titlebarAppearsTransparent`, `titleVisibility`, `fullSizeContentView`, or hide `NSVisualEffectView` — the SwiftUI modifier handles all of it.

`@Observable` classes break synthesized `Codable` conformance (the macro adds stored properties). Write manual `CodingKeys`, `convenience init(from:)` delegating to the designated initializer, and `encode(to:)`. For persistable IDs, change `let id = UUID()` to `let id: UUID` with `id: UUID = UUID()` default parameter. Add a separate restoration init accepting all persisted fields; derive counters from restored data (e.g., `paneCounter = rootNode.allPanes().count`).

Recursive `@Observable` enums with associated values (e.g., `SplitNode.SplitContent`) need a manual `type` discriminator field (`"leaf"` / `"split"`) for Codable — Swift enums with associated values don't auto-synthesize it.

`UUID` does not conform to `Transferable` on macOS 14. For drag-and-drop, use `.draggable(id.uuidString)` and `.dropDestination(for: String.self)`, converting back with `UUID(uuidString:)`.

When a view receives an `@Observable` object as a parameter and needs a `$binding` to one of its properties, declare it as `@Bindable var` instead of `let`. Without `@Bindable`, `$object.property` won't compile.

Never expose public mutable dictionaries on singletons (e.g., `var pendingItems: [UUID: T]`). Use register/consume method pairs (`registerItem(_:)` / `consumeItem(for:)`) to encapsulate the lifecycle and prevent implicit coupling between unrelated call sites.

When refactoring stored properties to computed aggregates (e.g., `Tab.isRunning` aggregating panes), update all direct assignment sites — tests, view callbacks, and model methods that set the old stored property will fail to compile.

For draggable dividers/resizable panes, never mutate `@Observable` properties on every drag frame — causes full observation propagation and layout stutter. Use `@GestureState` for the in-flight delta (commit to model on `.onEnded` only) and `GeometryReader` + `ZStack` with absolute positioning instead of `HStack`/`VStack` layout negotiation.

With `.windowStyle(.hiddenTitleBar)`, `GeometryReader` reports width excluding safe area insets. When using `.clipped()` on a container, set `.frame(width:)` to the full width (geometry + safe area insets) *before* `.clipped()` — otherwise content beyond the safe-area-constrained width is invisibly clipped away.
