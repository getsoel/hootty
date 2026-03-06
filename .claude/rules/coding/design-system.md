---
globs: Sources/Hootty/Views/**/*.swift, Sources/HoottyCore/DesignTokens.swift
---

Always use the design system defined in `Sources/HoottyCore/DesignTokens.swift`. The canonical reference is `docs/DESIGN.md`.

In views, derive tokens via `DesignTokens.from(theme)` and use semantic token properties (`tokens.text`, `tokens.surface`, `tokens.border`, etc.). Never access raw `TerminalTheme` properties (`theme.foreground`, `theme.sidebarSurface`, `theme.mantle`, etc.) directly in view code.

Use `Spacing.*` constants (`xs`, `sm`, `md`, `lg`, `xl`) for all padding, gaps, and insets. Never hardcode spacing values like `.padding(8)` — use `.padding(Spacing.md)`.

Use `TypeScale.*` constants (`bodySize`, `captionSize`, `smallSize`, `iconSize`) for font sizes. Never hardcode sizes like `.font(.system(size: 13))` — use `.font(.system(size: TypeScale.bodySize))`.

Component patterns (sidebar, tab bar, split panes, terminal surface, window chrome) and their expected token usage are documented in `docs/DESIGN.md` under "Component Patterns". Follow those mappings when building or modifying components.

If a new semantic role is needed that doesn't map to an existing token, add it to `DesignTokens` and document it in `docs/DESIGN.md` — don't use raw theme properties as a workaround.

Sidebar hover/selection backgrounds use sharp `Rectangle()` fills, never `RoundedRectangle`. No rounded corners in sidebar UI.
