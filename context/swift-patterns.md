# Swift patterns

Use when: writing or editing any Swift code (@Observable, Codable, SPM, MainActor gotchas).

## @Observable

- Never use `@State` with an array of `@Observable` classes combined with `@Binding` in the App struct - causes `swift_release` EXC_BAD_ACCESS crash. Use an `@Observable` model class held by `@State` instead (e.g., `@State private var appModel = AppModel()`).
- On `@Observable` classes, never use computed properties that allocate objects (NSColor, NSFont, etc.) - they re-allocate on every access/render. Use `private(set) var` cached values updated in `didSet` instead.
- All `@Observable` classes must be `@MainActor`. When adding `@MainActor` to classes with manual `Codable` conformance, use `extension Foo: @preconcurrency Codable` - the `init(from:)` and `encode(to:)` methods inherit actor isolation and can't satisfy the nonisolated protocol requirement otherwise.

## MainActor

- On `@MainActor` classes, mark static `let` constants with `Sendable` types and pure static functions (parsers, formatters) as `nonisolated` so they're accessible from non-main-actor contexts. Instance methods that only read from disk (no mutable state) can also be `nonisolated`.
- Default parameter expressions for `@MainActor` types fail in nonisolated context - `func foo(config: ConfigFile = ConfigFile())` won't compile. Use optional + resolve inside the body: `func foo(config: ConfigFile? = nil) { let resolved = config ?? ConfigFile() }`.

## Codable

- `@Observable` classes break synthesized `Codable` conformance (the macro adds stored properties). Write manual `CodingKeys`, `convenience init(from:)` delegating to the designated initializer, and `encode(to:)`. For persistable IDs, change `let id = UUID()` to `let id: UUID` with `id: UUID = UUID()` default parameter. Add a separate restoration init accepting all persisted fields; derive counters from restored data (e.g., `paneCounter = rootNode.allPanes().count`).
- Recursive `@Observable` enums with associated values (e.g., `SplitNode.SplitContent`) need a manual `type` discriminator field (`"leaf"` / `"split"`) for Codable - Swift enums with associated values don't auto-synthesize it.

## SPM / build

- SPM executables need `NSApplication.shared.setActivationPolicy(.regular)` in the App's `init()` to get a proper window. Standard workaround for non-bundled SwiftUI apps.
- SPM `swift build` does not compile `.xcassets` in library dependencies - it copies the raw directory but never invokes `actool`, so `Bundle.module.image(forResource:)` returns nil at runtime. Use `xcodebuild` (via `make build` / `make run`) to build the app; it compiles asset catalogs automatically.
- `actool --compile` into flat SPM bundle directories (no `Contents/Resources/` structure) does not fix xcassets loading - `NSBundle.image(forResource:)` only searches `Assets.car` in properly structured bundles. Don't attempt post-build actool workarounds with `swift build`; use `xcodebuild` instead.

## Standard library / UI kit

- `Array.remove(atOffsets:)` is a SwiftUI extension, not Foundation. In UI-free targets (HoottyCore), use manual reverse iteration: `for index in offsets.reversed() { array.remove(at: index) }`.
- `UUID` does not conform to `Transferable` on macOS 14. For drag-and-drop, use `.draggable(id.uuidString)` and `.dropDestination(for: String.self)`, converting back with `UUID(uuidString:)`.

## @Bindable

- When a view receives an `@Observable` object as a parameter and needs a `$binding` to one of its properties, declare it as `@Bindable var` instead of `let`. Without `@Bindable`, `$object.property` won't compile.

## Encapsulation

- Never expose public mutable dictionaries on singletons (e.g., `var pendingItems: [UUID: T]`). Use register/consume method pairs (`registerItem(_:)` / `consumeItem(for:)`) to encapsulate the lifecycle and prevent implicit coupling between unrelated call sites.
- When refactoring stored properties to computed aggregates (e.g., `Tab.isRunning` aggregating panes), update all direct assignment sites - tests, view callbacks, and model methods that set the old stored property will fail to compile.
