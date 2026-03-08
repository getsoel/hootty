# Theming

Hootty uses the [Catppuccin](https://catppuccin.com/) color palette with four built-in flavors. Themes apply to the entire interface — sidebar, tab bars, terminal, and window chrome.

## Usage

### Selecting a theme

Open the **Theme** menu in the menu bar and choose a flavor:

- **Latte** — light theme with warm pastels.
- **Frappe** — dark theme with cool tones.
- **Macchiato** — dark theme, slightly warmer than Frappe.
- **Mocha** — the darkest theme with warm accents.

A checkmark indicates the active flavor.

### Live switching

Theme changes apply instantly across all views and terminal surfaces. There's no restart required.

## Details

- The selected theme is persisted to UserDefaults and restored on launch. The default is Mocha.
- The window appearance automatically switches between light (Latte) and dark (Frappe, Macchiato, Mocha) modes, matching the macOS system chrome.
- Terminal colors (background, foreground, ANSI palette, cursor, selection) are derived from the Catppuccin flavor.
- User ghostty configuration files can override the theme defaults for terminal-specific settings.

### Color roles

The theme provides semantic color roles used throughout the interface:

| Role | Usage |
|------|-------|
| Background | Window chrome, title bar area |
| Surface Low | Sidebar background, tab bar background |
| Surface | Primary content area, terminal background |
| Surface Highlight | Hover and selection backgrounds |
| Text | Primary labels and content |
| Text Muted | Secondary labels, dimmed content |
| Text Accent | Links, focused borders |
| Border | Dividers, panel separators |
| Status Success | Running indicators (green) |
| Status Warning | Attention indicators (yellow) |
| Status Error | Error indicators (red) |

### Spacing and typography

Consistent spacing and font sizes are used across all components:

- **Spacing**: 2pt (xs), 4pt (sm), 8pt (md), 12pt (lg), 16pt (xl).
- **Font sizes**: 11pt (captions, tabs), 12pt (buttons), 13pt (body text, sidebar labels), 16pt (icons).
