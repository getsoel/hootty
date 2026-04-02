# Tasks: Custom Sidebar Scrollbar

## 1. Scroll Offset Tracking Infrastructure

- [x] 1.1 Add `.coordinateSpace(name: "sidebarScroll")` to the `ScrollView` in `WorkspaceSidebar.workspaceList`
- [x] 1.2 Add a zero-frame `GeometryReader` as `.background` on the scroll content `VStack` to read `minY` and content height in the named coordinate space
- [x] 1.3 Add `@State` properties for `scrollOffset`, `contentHeight`, and `visibleHeight` to `WorkspaceSidebar`
- [x] 1.4 Propagate geometry values via `.onChange(of:)` to the state properties
- [x] 1.5 Add `.scrollIndicators(.hidden)` to the `ScrollView`

## 2. SidebarScrollbar View

- [x] 2.1 Create `Sources/Hootty/Views/SidebarScrollbar.swift` with a view that accepts `contentHeight`, `visibleHeight`, `scrollOffset`, `tokens`, and `onScroll: (CGFloat) -> Void` callback
- [x] 2.2 Compute thumb height as `max(24, visibleHeight * (visibleHeight / contentHeight))` and thumb Y position proportional to scroll offset
- [x] 2.3 Draw the thumb as a 4pt-wide `RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)` filled with `tokens.textMuted` at variable opacity
- [x] 2.4 Place thumb within a 6pt-wide hit area, inset `Spacing.xs` from the trailing edge
- [x] 2.5 Hide the scrollbar entirely when `contentHeight <= visibleHeight` (no overflow)

## 3. Hover and Opacity States

- [x] 3.1 Add `@State var isHovered: Bool` on `SidebarScrollbar` using `.onContinuousHover` on the track area
- [x] 3.2 Accept a `sidebarHovered: Bool` parameter to control fade-in/fade-out (sidebar-level hover)
- [x] 3.3 Implement three-tier opacity: 40% default, 70% track hovered, 90% dragging
- [x] 3.4 Animate visibility with `.animation(.easeInOut(duration: 0.2))`

## 4. Drag-to-Scroll Interaction

- [x] 4.1 Add `@GestureState var dragDelta: CGFloat` for in-flight thumb drag offset
- [x] 4.2 Add `DragGesture` on the thumb that updates `dragDelta` and calls `onScroll` with the proportional target ratio on `.onEnded`
- [x] 4.3 Visually offset the thumb by `dragDelta` during the gesture (without committing to scroll position mid-drag)

## 5. Click-to-Jump Interaction

- [x] 5.1 Add `.onTapGesture` (with coordinate space) on the track background to detect click position
- [x] 5.2 Map click Y position to a scroll offset ratio and call `onScroll`

## 6. ScrollViewReader Integration

- [x] 6.1 Wrap `WorkspaceSidebar.workspaceList` content in `ScrollViewReader`
- [x] 6.2 Build a computed `scrollTargetIDs: [AnyHashable]` property that flattens workspace + pane IDs in display order
- [x] 6.3 Implement the `onScroll` handler: map ratio (0.0–1.0) to the nearest ID in `scrollTargetIDs`, call `proxy.scrollTo(id, anchor: .top)` with animation

## 7. Wire Up in WorkspaceSidebar

- [x] 7.1 Add `SidebarScrollbar` as `.overlay(alignment: .trailing)` on the `ScrollView`
- [x] 7.2 Add sidebar-level hover tracking (`.onHover`) and pass to `SidebarScrollbar.sidebarHovered`
- [x] 7.3 Verify scrollbar does not overlap the sidebar header

## 8. Validation

- [x] 8.1 `make build` succeeds
- [x] 8.2 `swift test` passes
- [x] 8.3 `make format-check` passes
- [x] 8.4 `make lint` passes
- [ ] 8.5 Manual test: scrollbar hidden when few workspaces, visible when many
- [ ] 8.6 Manual test: thumb position tracks scroll, drag and click interactions work
- [ ] 8.7 Manual test: keyboard navigation still works, no interference with drag-and-drop
