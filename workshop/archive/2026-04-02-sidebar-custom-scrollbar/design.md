# Design: Custom Sidebar Scrollbar

## Approach

Add a `SidebarScrollbar` view as a self-contained component in `Sources/Hootty/Views/SidebarScrollbar.swift`. It takes scroll geometry (content height, visible height, scroll offset) as inputs and outputs scroll-to requests via a callback. The `WorkspaceSidebar` orchestrates the data flow: a named coordinate space on the `ScrollView`, a `GeometryReader` inside the content to measure offset, and a `ScrollViewReader` to execute programmatic scrolls.

### Data Flow

```
ScrollView (coordinateSpace: "sidebarScroll")
  └─ VStack
       └─ GeometryReader → measures minY in "sidebarScroll" → scrollOffset state
  └─ .overlay(alignment: .trailing)
       └─ SidebarScrollbar(contentHeight:, visibleHeight:, scrollOffset:, onScroll:)
            └─ drag/click → onScroll(targetOffset) → ScrollViewReader.scrollTo(nearestID)
```

### Scroll Offset Tracking

Use a `GeometryReader` with zero frame placed as a background on the scroll content `VStack`. Read `geo.frame(in: .named("sidebarScroll")).minY` to get the current scroll offset (negative value as content scrolls up). Propagate via `.onChange(of:)` to a `@State var scrollOffset: CGFloat` on the sidebar.

Content height comes from the same geometry reader — `geo.frame(in: .named("sidebarScroll")).height` gives the content size. Visible height comes from the outer `ScrollView` geometry.

### Programmatic Scrolling from Thumb Interaction

`ScrollViewReader` wraps the scroll content. When the user drags the thumb or clicks the track, `SidebarScrollbar` calls `onScroll(targetOffsetRatio: CGFloat)` where the ratio is 0.0 (top) to 1.0 (bottom). The sidebar maps this to the nearest workspace/pane ID by index proportion and calls `proxy.scrollTo(id, anchor: .top)`.

To build the ID list for scroll targeting, flatten the visible workspace + pane hierarchy into an ordered array of identifiable IDs. This list already exists implicitly in the `ForEach` — extract it into a computed property.

## Key Decisions

**Pure SwiftUI overlay, no AppKit bridging.** The codebase rule is to stay in SwiftUI unless forced out. The scroll position APIs (`GeometryReader` + named coordinate space) are sufficient for this use case. No `NSScrollView` access needed.

**`@GestureState` for drag delta.** Per the SwiftUI rules in `.claude/rules/coding/swiftui.md`, never mutate `@Observable` on every drag frame. Use `@GestureState` for in-flight thumb offset, commit on `.onEnded`.

**Separate extracted file.** `SidebarScrollbar` is a self-contained primitive that takes all inputs as params — fits the extraction rule. It goes in `Sources/Hootty/Views/SidebarScrollbar.swift`.

**ID-based scroll targeting (not pixel offset).** SwiftUI's `ScrollViewReader.scrollTo` works with identifiable items, not pixel offsets. The mapping from thumb ratio → nearest ID is approximate but sufficient for a sidebar with discrete rows. This avoids fighting SwiftUI's scroll system.

**Fade on sidebar hover, not scroll region hover.** The scrollbar appears when the mouse enters the sidebar area (tracked by existing `sidebarHasFocus` or a new hover state), not just when hovering the narrow scrollbar track. This matches user expectation — the scrollbar is a sidebar feature, not a hidden target.

## Dependencies

None. Pure SwiftUI, uses existing design tokens.
