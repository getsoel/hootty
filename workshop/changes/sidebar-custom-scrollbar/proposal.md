# Proposal: Custom Sidebar Scrollbar

## Why

The sidebar uses a vanilla SwiftUI `ScrollView` with the default macOS auto-hiding scroller. This system scroller is visually disconnected from the Catppuccin-themed UI — it appears as a grey overlay that fades in/out, clashing with the dark sidebar surface. A custom-drawn scrollbar that uses design tokens would feel native to the app and provide a persistent visual cue for scroll position, similar to VS Code's minimap scrollbar or other modern terminal emulators.

## What Changes

- Add a custom scrollbar overlay to the sidebar `ScrollView` in `WorkspaceSidebar.swift`
- Create a new `SidebarScrollbar.swift` view that draws a thin track + thumb using design tokens
- Track scroll offset via `GeometryReader` coordinate space on the scroll content
- Hide the default system scroller via `.scrollIndicators(.hidden)`
- Support hover-to-reveal, click-to-jump, and drag-to-scroll interactions on the custom scrollbar

## Capabilities

### New Capabilities

- **sidebar-scrollbar**: A custom-drawn scrollbar overlay for the workspace sidebar that uses design tokens for theming, appears on hover, and supports click-to-jump and drag-to-scroll interaction.

### Modified Capabilities

(none)

## Impact

- **Dependencies:** None — pure SwiftUI, no new packages
- **Database/API:** None
- **Other systems:** No impact on keyboard navigation, drag-and-drop, or sidebar resizing. The scrollbar overlays the existing `ScrollView` content without changing the scroll container structure.
