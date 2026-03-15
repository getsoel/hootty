# Hootty Design System

A Zed-inspired design system for Hootty's macOS terminal emulator UI.
Implemented in `Sources/HoottyCore/DesignTokens.swift`.

---

## Design Principles

1. **Speed-first aesthetic** -- The terminal surface dominates the viewport. All chrome (sidebar, tab bar, dividers) is visually recessive.
2. **Semantic color tokens** -- Views reference named roles (`text`, `surface`, `border`) instead of raw theme properties (`theme.foreground`, `theme.sidebarSurface`). This decouples UI code from the palette.
3. **Layered surfaces** -- Four depth levels create visual hierarchy: `background` < `surfaceLow` < `surface` < `surfaceHighlight`.
4. **Dark-first, light-capable** -- All four Catppuccin flavors (Mocha, Macchiato, Frappe, Latte) are supported. Dark flavors are the default experience; Latte inverts the layer ordering naturally.
5. **Minimal motion** -- Transitions are fast and purposeful. No decorative animation.

---

## Color Architecture

Modeled after [Zed's theme token system](https://zed.dev/docs/extensions/themes). Each token maps to a `TerminalTheme` property and ultimately to a Catppuccin palette role.

### Surface Layers

Four semantic depth levels are defined, but chrome shares the terminal background (no crust/mantle depth layers). In practice, `background`, `surfaceLow`, and `surface` all map to the same color. Only `surfaceHighlight` differs.

| Token | Zed Equivalent | TerminalTheme Property | Actual Mapping |
|-------|---------------|----------------------|----------------|
| `background` | `background` | `background` | theme.background |
| `surfaceLow` | `panel.background` | `background` | theme.background (same as above) |
| `surface` | `surface.background` | `background` | theme.background (same as above) |
| `surfaceHighlight` | `elevated_surface.background` | `palette[0]` | theme.palette[0] (Surface1) |

### Element States

Interactive element backgrounds for hover/selection feedback. Uses accent (Blue, palette[4]) tint to avoid contrast collisions where selectionBackground matches textMuted (e.g., Catppuccin Latte).

| Token | Zed Equivalent | Derivation |
|-------|---------------|------------|
| `elementHover` | `element.hover` | `palette[4]` (Blue) @ 8% opacity |
| `elementSelected` | `element.selected` | `palette[4]` (Blue) @ 15% opacity |
| `elementSelectedText` | -- | `theme.foreground` (always) |

### Text Hierarchy

Three levels of text prominence:

| Token | Zed Equivalent | TerminalTheme Property | Catppuccin Role |
|-------|---------------|----------------------|-----------------|
| `text` | `text` | `foreground` | Text |
| `textMuted` | `text.muted` | `palette[7]` | Subtext1 |
| `textAccent` | `text.accent` | `palette[5]` | Pink |
| `textRepo` | -- | `palette[6]` | Teal |
| `textBranch` | -- | `palette[4]` | Blue |
| `textTree` | -- | `palette[3]` | Yellow |

### Borders

| Token | Zed Equivalent | TerminalTheme Property | Catppuccin Role |
|-------|---------------|----------------------|-----------------|
| `border` | `border` | `palette[0]` | Surface1 |
| `borderFocused` | `pane.focused_border` | `foreground` | Text |

### Status Colors

Semantic status indicators for process state and alerts:

| Token | Zed Equivalent | TerminalTheme Property | Catppuccin Role |
|-------|---------------|----------------------|-----------------|
| `statusSuccess` | `success` | `palette[2]` | Green |
| `statusInactive` | `ignored` | `palette[8]` | Overlay0 |
| `statusWarning` | `warning` | `palette[3]` | Yellow |
| `statusError` | `error` | `palette[1]` | Red |
| `statusThinking` | -- | `palette[4]` | Blue |
| `statusBell` | -- | `palette[2]` | Green |
| `statusDone` | -- | `palette[2]` | Green |

### Component-Specific Tokens

| Token | Zed Equivalent | Derivation |
|-------|---------------|------------|
| `tabBarBackground` | `tab_bar.background` | Same as `background` (theme.background) |
| `tabActive` | `tab.active_background` | Same as `background` (theme.background) |
| (tab inactive) | `tab.inactive_background` | `Color.clear` (no dedicated token -- use transparency) |
| `scrim` | -- | `NSColor.black` @ 30% opacity (modal backdrop) |
| `unfocusedDimColor` | -- | `NSColor.black` @ 50% opacity (darkens entire unfocused pane) |

---

## Typography Scale

Three type sizes covering all non-terminal UI text. Terminal text size is controlled by ghostty configuration, not this scale.

| Role | Size | Weight | Usage |
|------|------|--------|-------|
| `body` | 13pt | Regular | Sidebar labels, workspace names |
| `caption` | 11pt | Regular | Tab labels, badge counts |
| `small` | 12pt | Regular | Buttons, secondary actions |
| `icon` | 16pt | Regular | SF Symbol icons (use `.font(.system(size: TypeScale.iconSize))`) |

Font construction uses `Font.system(size:weight:)` in SwiftUI views. `TypeScale` provides the raw size constants since `HoottyCore` cannot import SwiftUI.

---

## Spacing Scale

4pt base unit. All spacing in the UI should use these values:

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 2pt | Micro gaps (e.g., icon-to-text in tight layouts) |
| `sm` | 4pt | Icon padding, small insets |
| `smd` | 6pt | Dense row padding |
| `md` | 8pt | Row padding, standard gaps between elements |
| `lg` | 12pt | Section padding, group separators |
| `xl` | 16pt | Container padding, outer margins |

---

## Layout Constants

### Bar Height

All horizontal bars must share the same height (`Layout.barHeight`, 38pt) to maintain visual alignment across the window. This includes:

- **Sidebar header bar** (`WorkspaceSidebar`)
- **Tab bar** (`PaneGroupTabBar`)
- **Pipeline bar** (`PipelineBoardView`)
- **Titlebar** (NSToolbar, sized to match via safe area)

Never hardcode `38` in view code — always use `Layout.barHeight`. If a new bar-like component is added, it must use this constant.

---

## Component Patterns

### Sidebar

#### Container

- Background: `surfaceLow`
- Width: configurable (`sidebarWidth`, default 260, min 140, max 400)
- Layout: `VStack(spacing: 0)` — scrollable workspace list, 1pt `border` divider, add-workspace button
- Keyboard nav: up/down arrows navigate panes, return/escape release focus

#### Tree Layout System

- `TreeLayout.columnWidth = 22pt` — shared by tree connector gutters and icon frames
- Tree connector: `Canvas` drawing vertical lines at `(level - 0.5) * columnWidth` per depth level
- Line style: `textMuted` @ 30% opacity, 1pt stroke
- Icon frames use `columnWidth` (22pt) so icon centers align with tree continuation lines across rows
- Depths: workspace = 0 (no connector), branch header = 1, pane = 1 (flat) or 2 (grouped)

#### Row Types

**Workspace row (depth 0)**

- Icon: `folder.fill`, `iconSize`, `textMuted`, frame `columnWidth`
- Text: `bodySize`, `textMuted`
- Padding: `Spacing.md` horizontal + vertical
- Background: clear / `elementHover` on hover
- Drag-and-drop reorderable with 2pt `textAccent` drop indicator
- Context menu: Rename Workspace, Close Workspace

**Branch section header (depth 1)**

- Icon: `cube.fill` (`textAccent`) for named branches, `cube.transparent` (`textMuted`) for ungrouped
- Text: `bodySize`, `textBranch` (Blue) for branch name, `textRepo` (Teal) for repo prefix, `textTree` (Yellow) for "(tree)" indicator, `textMuted` for "(no branch)"
- Padding: inner `Spacing.md` vertical + trailing, outer `Spacing.md` leading
- Non-interactive: no hover state, no selection, no context menu
- Only shown when `workspace.hasBranchSections` (any pane has a branch)
- Sort: HEAD branch first, then alphabetical, ungrouped last

**Pane row (depth 1 or 2)**

- Icon: `StatusDotView` — see Status Indicators below
- Text: `bodySize`, `textMuted`, shows `pane.displayName`
- Worktree badge: `captionSize`, `textMuted`, "(tree)" — shown when `pane.worktreePath != nil`
- Split thumbnail: 24×16pt `Canvas` minimap when workspace has multiple panes
- Padding: inner `Spacing.md` vertical + trailing, outer `Spacing.md` leading
- Background: clear / `elementHover` on hover / `elementSelected` when focused
- Context menu: Rename Pane, New Worktree (if pane has branch), Close Pane (if multi-pane)

#### Add Workspace Button

- Icon: `plus`, `smallSize`
- Text: "New Workspace", `smallSize`, `textMuted`
- Padding: `Spacing.lg` horizontal, `Spacing.md` vertical
- `.plain` button style

#### Status Indicators (StatusDotView)

| State | Icon | Color Token | Animation |
|-------|------|-------------|-----------|
| Default | `apple.terminal` | `textMuted` | — |
| Attention | `bell` | `statusBell` (Green) | — |
| Thinking | `arrow.2.circlepath` | `textMuted` | 1.5s linear rotation |
| Done | `checkmark.circle` | `statusDone` (Green) | — |

All use `iconSize` (16pt) within `columnWidth` (22pt) frame.

#### Visual State Matrix

| Row Type | Default | Hover | Selected |
|----------|---------|-------|----------|
| Workspace | clear | `elementHover` | — |
| Branch header | clear | — | — |
| Pane | clear | `elementHover` | `elementSelected` |

### Tab Bar

- Background: `tabBarBackground` (theme.background)
- Active tab: `tabActive` (theme.background), `text` label
- Inactive tab: transparent, `textMuted` label
- Tab separator: `border`
- Close button: `textMuted`, hover `text`

### Split Panes

- Divider: `border` (1pt)
- Focused pane border: `borderFocused` (2pt)
- Divider drag cursor: `NSCursor.resizeLeftRight` / `resizeUpDown`

### Terminal Surface

- Background: `surface` (Base) -- rendered by ghostty, not SwiftUI
- No additional chrome overlaid on the terminal

### Window Chrome

- `.windowStyle(.hiddenTitleBar)` -- traffic lights only
- Title bar area: `background` (theme.background), same as sidebar/tab bar

---

## Interaction States

| State | Visual Treatment |
|-------|-----------------|
| Default | Base background, no highlight |
| Hover | `elementHover` background |
| Selected | `elementSelected` background |
| Focused + Selected | `elementSelected` + `borderFocused` accent |
| Dragging | `elementSelected` + slight scale or shadow |
| Attention | `statusWarning` pulse on status indicator |

---

## Animation Timing

| Animation | Duration | Curve |
|-----------|----------|-------|
| Hover transition | 0.15s | ease-in-out |
| Tab switch | 0.1s | ease-out |
| Sidebar expand/collapse | 0.2s | spring (response 0.3, damping 0.8) |
| Split resize | real-time (gesture-driven) | -- |

---

## Zed vs Hootty Comparison

| Concept | Zed | Hootty |
|---------|-----|--------|
| Theme system | JSON theme files, 200+ tokens | 4 Catppuccin flavors, ~16 semantic tokens |
| Surface layers | 4 (background, surface, elevated, wash) | 4 (background, surfaceLow, surface, surfaceHighlight) |
| Typography | 4+ sizes, configurable font | 3 sizes, system font (terminal font via ghostty) |
| Spacing | 4px base grid | 4pt base grid (matching) |
| Tab model | Per-pane tab bar | Per-region tab groups |
| Split panes | Binary tree | Binary tree (SplitNode) |
| Terminal rendering | Custom GPU renderer | libghostty (Metal) |
| Theme source | Community extensions | Built-in Catppuccin palettes |

---

## Usage

```swift
import HoottyCore

let theme = TerminalTheme.catppuccin(.mocha)
let tokens = DesignTokens.from(theme)

// In SwiftUI views:
Text("Hello")
    .foregroundColor(Color(nsColor: tokens.text))
    .font(.system(size: TypeScale.bodySize))
    .padding(Spacing.md)
```

---

## File Reference

| File | Purpose |
|------|---------|
| `Sources/HoottyCore/TerminalTheme.swift` | Raw Catppuccin palettes and theme struct |
| `Sources/HoottyCore/ThemeManager.swift` | Persisted theme selection |
| `Sources/HoottyCore/DesignTokens.swift` | Semantic token layer (this design system) |
| `docs/DESIGN.md` | This document |
