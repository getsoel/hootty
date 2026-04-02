# Spec: Sidebar Scrollbar

## Overview

A custom-drawn scrollbar overlay for the workspace sidebar that replaces the default macOS scroller with a themed, interactive indicator.

## Visibility

- The scrollbar MUST be hidden when all sidebar content fits within the visible area (no overflow).
- The scrollbar MUST appear when the sidebar content overflows the visible area.
- The scrollbar SHOULD fade in when the mouse enters the sidebar region and fade out when it leaves.
- The fade animation SHOULD use a 0.2s duration with easeInOut timing.
- The scrollbar MUST become fully opaque while being dragged, regardless of mouse position.
- The default system scroller MUST be hidden via `.scrollIndicators(.hidden)`.

## Layout

- The scrollbar MUST be rendered as an overlay on the right edge of the sidebar `ScrollView`.
- The scrollbar track MUST span the full height of the visible scroll area.
- The scrollbar MUST have a width of 6pt for the track hit area.
- The visible thumb MUST be 4pt wide, centered within the 6pt track.
- The scrollbar MUST be inset `Spacing.xs` (2pt) from the right edge of the sidebar.
- The scrollbar MUST NOT overlap the sidebar header (it spans only the scroll region).

## Thumb Sizing

- The thumb height MUST be proportional to the ratio of visible height to total content height: `thumbHeight = visibleHeight * (visibleHeight / contentHeight)`.
- The thumb MUST have a minimum height of 24pt to remain grabbable.
- The thumb position MUST reflect the current scroll offset proportionally within the available track space.

## Theming

- The track MUST be invisible (no background fill) in the default state.
- The thumb MUST use `tokens.textMuted` with 40% opacity in the default (hover-revealed) state.
- The thumb MUST use `tokens.textMuted` with 70% opacity when the mouse hovers directly over the scrollbar track.
- The thumb MUST use `tokens.textMuted` with 90% opacity while being actively dragged.
- The thumb MUST use `Layout.cornerRadiusSm` (4pt) for rounded ends.

## Scroll Position Tracking

- The scroll offset MUST be tracked via a `GeometryReader` inside the scroll content, measuring against a named coordinate space on the `ScrollView`.
- The coordinate space MUST be named to avoid conflicts (e.g., `"sidebarScroll"`).
- Offset tracking MUST NOT cause excessive re-renders — the geometry reading SHOULD use a `PreferenceKey` or `.onChange` to propagate values only when changed.

## Interaction: Drag-to-Scroll

- The user MUST be able to drag the thumb to scroll the sidebar content.
- Dragging MUST use `@GestureState` for the in-flight delta, committing to the scroll position only on gesture end.
- The drag MUST map thumb position to scroll offset proportionally: `scrollOffset = (thumbY / trackHeight) * contentHeight`.
- Scrolling via drag MUST use `ScrollViewReader.scrollTo()` targeting the nearest item ID.

## Interaction: Click-to-Jump

- Clicking on the track (outside the thumb) MUST scroll to the proportional position of the click.
- The click target MUST be the full 6pt-wide track area.
- Click-to-jump SHOULD animate the scroll with `.easeInOut` timing.

## Accessibility

- The custom scrollbar MAY be invisible to VoiceOver since the underlying `ScrollView` retains native accessibility scrolling.
- The scrollbar MUST NOT interfere with keyboard navigation (up/down arrow keys handled by `SidebarKeyboardNav`).

## Performance

- The scrollbar view MUST NOT cause the sidebar content to re-render when the thumb position updates.
- Geometry reads and thumb repositioning SHOULD target 60fps during active scrolling.
