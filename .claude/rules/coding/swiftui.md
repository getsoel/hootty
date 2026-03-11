---
globs: Sources/Hootty/Views/**/*.swift, Sources/Hootty/HoottyApp.swift
---

`HoottyCore.Tab` collides with `SwiftUI.Tab` (macOS 15+). In view code, qualify as `HoottyCore.Tab` in function signatures to disambiguate.

When the Swift compiler reports "unable to type-check this expression in reasonable time", extract sub-views into private computed properties or helper functions to reduce body complexity.

For custom titlebars (traffic lights only, no chrome), use `.windowStyle(.hiddenTitleBar)` on the `WindowGroup`. Do not manually set `titlebarAppearsTransparent`, `titleVisibility`, `fullSizeContentView`, or hide `NSVisualEffectView` — the SwiftUI modifier handles all of it.

For draggable dividers/resizable panes, never mutate `@Observable` properties on every drag frame — causes full observation propagation and layout stutter. Use `@GestureState` for the in-flight delta (commit to model on `.onEnded` only) and `GeometryReader` + `ZStack` with absolute positioning instead of `HStack`/`VStack` layout negotiation.

With `.windowStyle(.hiddenTitleBar)`, `GeometryReader` reports width excluding safe area insets. When using `.clipped()` on a container, set `.frame(width:)` to the full width (geometry + safe area insets) *before* `.clipped()` — otherwise content beyond the safe-area-constrained width is invisibly clipped away.

Never use `NSViewRepresentable` as `.overlay` on interactive SwiftUI views — the embedded NSView intercepts all mouse events, breaking `.onHover`, `.onTapGesture`, and gesture recognizers on the view underneath.

Cursor management differs between AppKit and SwiftUI contexts. For NSView subclasses: add `.cursorUpdate` to `NSTrackingArea` options and override `cursorUpdate(with:)` to call `cursor.set()` — this fires at the AppKit level before SwiftUI can interfere. For SwiftUI views (macOS 14, pre-`.pointerStyle`): use `.onContinuousHover` with `DispatchQueue.main.async { NSCursor.pointingHand.set() }`. One-shot `NSCursor.set()` or `.push()`/`.pop()` in `.onHover` gets immediately overridden because SwiftUI resets cursors on every mouse move.

Never use `.resizable().frame(width:height:)` on Catppuccin SVG icons — they have a 16x16 viewBox and scaling causes bitmap blur on thin strokes. Use `.frame(width:height:)` alone to render at native size. Keep `.resizable()` only for SF Symbols.

`.foregroundStyle()` is a no-op on `Image(nsImage:)` when the NSImage is a non-template image (e.g., SVGs with baked-in stroke colors). Don't pass tint colors to Catppuccin icon views — the SVGs already carry their Catppuccin palette colors.

For continuous tree/indent lines drawn with `Canvas` across consecutive rows in a `LazyVStack(spacing: 0)`, place `.padding(.vertical:)` on the inner content view, not the outer row container. Outer padding creates gaps between rows where the Canvas doesn't draw, breaking line continuity.

macOS `ScrollView(.horizontal)` silently discards vertical scroll wheel events — the inner NSScrollView consumes them before they propagate up the responder chain. Overriding `scrollWheel(with:)` on a parent NSView does NOT work. Use `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)` to intercept globally, check if the mouse is within bounds, convert deltaY to deltaX via `CGEvent.setDoubleValueField`, and send directly to the NSScrollView via `scrollView.scrollWheel(with:)`. Return `nil` from the monitor to consume the original event.

When views inside a fixed-height container (e.g., a 38pt tab bar) use small fixed frames (e.g., 24x24 buttons), `.overlay` borders are constrained to the content height, not the container height. Apply `.frame(maxHeight: .infinity)` on the HStack/group so it fills the container. For square buttons that fill the bar height, use `.frame(maxWidth: .infinity, maxHeight: .infinity).aspectRatio(1, contentMode: .fit)`.

Never use `if condition { View() }` to show/hide elements when the surrounding layout should stay stable (e.g., a close button appearing on hover inside a variable-width tab). The conditional insertion changes the HStack's intrinsic size. Use `.opacity(0)` / `.opacity(1)` to keep the element in the layout tree while hiding it visually.

**Extract into a separate file** when a UI component is used across 2+ view files, OR is a self-contained primitive with no dependency on parent state (takes all inputs as params). **Keep inline (private)** when a component is used only within one file AND is tightly coupled to parent state (e.g., references parent's `@State` hover enum). Extracted files go in `Sources/Hootty/Views/` flat alongside other views, prefixed descriptively (no `Components/` subfolder unless count exceeds ~5 extracted primitives).

Always add `.contentShape(Rectangle())` before `.onTapGesture` on container views (HStacks, tab rows, toolbar items). Without it, taps only register on visible content (text, icons), not the empty space within the container's frame.

When visually balancing left/right elements in an HStack (e.g., status indicator and close button flanking a label), compute total rendered size (icon size + padding on each side) to ensure both containers occupy the same width. A 10pt icon with `Spacing.sm` padding ≠ a 20pt frame with `Spacing.sm` padding — the latter is 10pt wider.

`PreferenceKey` values set inside an `NSHostingView` (via `NSViewRepresentable`) don't reliably fire `.onPreferenceChange` within that hosting context. To report geometry out of an `NSViewRepresentable`, use `.onChange(of: geo.frame(in: .global), initial: true)` on a `GeometryReader` and call a closure callback directly. PreferenceKeys work normally outside the `NSViewRepresentable` boundary.

`@State` default initializers (`@State private var foo = Foo()`) run before the `init()` body regardless of source order. When initialization order matters (e.g., a side effect in `init()` must complete before a model is created), declare `@State private var foo: Type` and initialize via `_foo = State(initialValue:)` inside `init()`.
