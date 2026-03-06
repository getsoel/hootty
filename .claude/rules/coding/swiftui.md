---
globs: "**/*.swift"
---
Never use `@State` with an array of `@Observable` classes combined with `@Binding` in the App struct — causes swift_release EXC_BAD_ACCESS crash. Use an `@Observable` model class held by `@State` instead (e.g., `@State private var appModel = AppModel()`).

SPM executables need `NSApplication.shared.setActivationPolicy(.regular)` in the App's `init()` to get a proper window. This is a standard workaround for non-bundled SwiftUI apps.

`Array.remove(atOffsets:)` is a SwiftUI extension, not Foundation. In UI-free targets (HoottyCore), use manual reverse iteration: `for index in offsets.reversed() { array.remove(at: index) }`.

On `@Observable` classes, never use computed properties that allocate objects (NSColor, NSFont, etc.) — they re-allocate on every access/render. Use `private(set) var` cached values updated in `didSet` instead.

`HoottyCore.Tab` collides with `SwiftUI.Tab` (macOS 15+). In view code, qualify as `HoottyCore.Tab` in function signatures to disambiguate.

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

Never use `NSViewRepresentable` as `.overlay` on interactive SwiftUI views — the embedded NSView intercepts all mouse events, breaking `.onHover`, `.onTapGesture`, and gesture recognizers on the view underneath.

Cursor management differs between AppKit and SwiftUI contexts. For NSView subclasses: add `.cursorUpdate` to `NSTrackingArea` options and override `cursorUpdate(with:)` to call `cursor.set()` — this fires at the AppKit level before SwiftUI can interfere. For SwiftUI views (macOS 14, pre-`.pointerStyle`): use `.onContinuousHover` with `DispatchQueue.main.async { NSCursor.pointingHand.set() }`. One-shot `NSCursor.set()` or `.push()`/`.pop()` in `.onHover` gets immediately overridden because SwiftUI resets cursors on every mouse move.

Never use `.resizable().frame(width:height:)` on Catppuccin SVG icons — they have a 16x16 viewBox and scaling causes bitmap blur on thin strokes. Use `.frame(width:height:)` alone to render at native size. Keep `.resizable()` only for SF Symbols.

`.foregroundStyle()` is a no-op on `Image(nsImage:)` when the NSImage is a non-template image (e.g., SVGs with baked-in stroke colors). Don't pass tint colors to Catppuccin icon views — the SVGs already carry their Catppuccin palette colors.

For continuous tree/indent lines drawn with `Canvas` across consecutive rows in a `LazyVStack(spacing: 0)`, place `.padding(.vertical:)` on the inner content view, not the outer row container. Outer padding creates gaps between rows where the Canvas doesn't draw, breaking line continuity.

SPM `swift build` does not compile `.xcassets` in library dependencies — it copies the raw directory but never invokes `actool`, so `Bundle.module.image(forResource:)` returns nil at runtime. Use `xcodebuild` (via `make build`/`make run`) to build the app; it compiles asset catalogs automatically.

`actool --compile` into flat SPM bundle directories (no `Contents/Resources/` structure) does not fix xcassets loading — `NSBundle.image(forResource:)` only searches `Assets.car` in properly structured bundles. Don't attempt post-build actool workarounds with `swift build`; use `xcodebuild` instead.

macOS `ScrollView(.horizontal)` silently discards vertical scroll wheel events — the inner NSScrollView consumes them before they propagate up the responder chain. Overriding `scrollWheel(with:)` on a parent NSView does NOT work. Use `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)` to intercept globally, check if the mouse is within bounds, convert deltaY to deltaX via `CGEvent.setDoubleValueField`, and send directly to the NSScrollView via `scrollView.scrollWheel(with:)`. Return `nil` from the monitor to consume the original event.

When views inside a fixed-height container (e.g., a 38pt tab bar) use small fixed frames (e.g., 24x24 buttons), `.overlay` borders are constrained to the content height, not the container height. Apply `.frame(maxHeight: .infinity)` on the HStack/group so it fills the container. For square buttons that fill the bar height, use `.frame(maxWidth: .infinity, maxHeight: .infinity).aspectRatio(1, contentMode: .fit)`.

Never use `if condition { View() }` to show/hide elements when the surrounding layout should stay stable (e.g., a close button appearing on hover inside a variable-width tab). The conditional insertion changes the HStack's intrinsic size. Use `.opacity(0)` / `.opacity(1)` to keep the element in the layout tree while hiding it visually.
