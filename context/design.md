# Design system

Use when: creating or modifying UI components, working with design tokens, spacing, or theme colors.

Always use the design system defined in `Sources/HoottyCore/DesignTokens.swift`.

## Tokens

- Derive tokens via `DesignTokens.from(theme)` and use semantic token properties (`tokens.text`, `tokens.surface`, `tokens.border`, etc.).
- Never access raw `TerminalTheme` properties (`theme.foreground`, `theme.sidebarSurface`, `theme.mantle`, etc.) directly in view code.
- If a new semantic role is needed that doesn't map to an existing token, add it to `DesignTokens` - don't use raw theme properties as a workaround.

## Spacing

- Use `Spacing.*` constants (`xs`, `sm`, `md`, `lg`, `xl`) for all padding, gaps, and insets.
- Never hardcode spacing values like `.padding(8)` - use `.padding(Spacing.md)`.

## Type scale

- Use `TypeScale.*` constants (`bodySize`, `captionSize`, `smallSize`, `iconSize`) for font sizes.
- Never hardcode sizes like `.font(.system(size: 13))` - use `.font(.system(size: TypeScale.bodySize))`.

## Corner radius

- Use `Layout.cornerRadiusSm` (4pt), `Layout.cornerRadiusMd` (6pt), and `Layout.cornerRadiusLg` (8pt) for all rounded corners. Never hardcode `cornerRadius: 4/6/8`. `cornerRadius: 3` for tiny badge pills is fine as-is.

## Sidebar

- Sidebar hover/selection backgrounds use sharp `Rectangle()` fills, never `RoundedRectangle`. No rounded corners in sidebar UI.
