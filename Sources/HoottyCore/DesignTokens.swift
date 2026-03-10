import AppKit

/// Semantic design tokens derived from a TerminalTheme.
/// Modeled after Zed's theme token system.
///
/// Usage: `let tokens = DesignTokens.from(theme)`
/// Views consume these tokens instead of accessing raw theme properties directly.
public struct DesignTokens {
    // MARK: - Surface Layers (darkest to lightest in dark themes)

    /// Deepest background layer (window chrome, title bar area). Maps to Catppuccin Crust.
    public let background: NSColor

    /// Low-depth surface (sidebar, tab bar). Maps to Catppuccin Mantle.
    public let surfaceLow: NSColor

    /// Primary content surface (terminal area, panels). Maps to Catppuccin Base.
    public let surface: NSColor

    /// Elevated surface for highlighted regions (sidebar selection, hover cards). Maps to Catppuccin Surface0.
    public let surfaceHighlight: NSColor

    // MARK: - Element States

    /// Hover state for interactive elements. Semi-transparent surfaceHighlight.
    public let elementHover: NSColor

    /// Selected/active state for interactive elements. Solid surfaceHighlight.
    public let elementSelected: NSColor

    // MARK: - Text

    /// Primary text color. Maps to theme foreground.
    public let text: NSColor

    /// Secondary/subdued text. Maps to theme sidebarTextSecondary (Catppuccin Subtext0).
    public let textMuted: NSColor

    /// Accent text for links, highlights. Maps to palette[5] (Catppuccin Pink).
    public let textAccent: NSColor

    // MARK: - Borders

    /// Default border color for dividers and separators.
    public let border: NSColor

    /// Border color for focused panes/elements.
    public let borderFocused: NSColor

    // MARK: - Status

    /// Success/running state (green).
    public let statusSuccess: NSColor

    /// Inactive/stopped state (overlay0).
    public let statusInactive: NSColor

    /// Warning/attention state (yellow).
    public let statusWarning: NSColor

    /// Error state (red).
    public let statusError: NSColor

    /// Thinking/processing state (blue).
    public let statusThinking: NSColor

    // MARK: - Component-Specific

    /// Tab bar background. Same as background (Mantle).
    public let tabBarBackground: NSColor

    /// Active/selected tab background. Same as surface (Base).
    public let tabActive: NSColor

    /// Opacity of the black overlay applied to non-focused panes.
    public let unfocusedDimOpacity: CGFloat

    /// Returns the appropriate status color for an attention kind.
    public func attentionColor(for kind: AttentionKind) -> NSColor {
        switch kind {
        case .idle: return statusSuccess
        case .input: return statusWarning
        }
    }

    /// Derive semantic tokens from a TerminalTheme.
    /// Chrome shares the terminal background (no crust/mantle depth layers).
    /// Visual separation uses palette[0] highlights and borders.
    public static func from(_ theme: TerminalTheme) -> DesignTokens {
        DesignTokens(
            background: theme.background,
            surfaceLow: theme.background,
            surface: theme.background,
            surfaceHighlight: theme.palette[0],
            elementHover: theme.palette[0].withAlphaComponent(0.4),
            elementSelected: theme.palette[0],
            text: theme.foreground,
            textMuted: theme.palette[7],
            textAccent: theme.palette[5],
            border: theme.palette[0],
            borderFocused: theme.palette[5],
            statusSuccess: theme.palette[2],
            statusInactive: theme.palette[8],
            statusWarning: theme.palette[3],
            statusError: theme.palette[1],
            statusThinking: theme.palette[4],
            tabBarBackground: theme.background,
            tabActive: theme.background,
            unfocusedDimOpacity: 0.5
        )
    }
}

// MARK: - Spacing Scale (4pt base)

public enum Spacing {
    /// 2pt - Micro gaps, tight padding
    public static let xs: CGFloat = 2
    /// 4pt - Icon padding, small gaps
    public static let sm: CGFloat = 4
    /// 8pt - Row padding, standard gaps
    public static let md: CGFloat = 8
    /// 12pt - Section padding
    public static let lg: CGFloat = 12
    /// 16pt - Container padding
    public static let xl: CGFloat = 16
}

// MARK: - Typography Scale
// Font construction requires SwiftUI or AppKit font APIs.
// These constants define the size/weight pairs for views to consume.

public enum TypeScale {
    /// 13pt - Sidebar labels, workspace names
    public static let bodySize: CGFloat = 13
    /// 11pt - Tab labels, badge counts
    public static let captionSize: CGFloat = 11
    /// 12pt - Buttons, secondary actions
    public static let smallSize: CGFloat = 12
    /// 16pt - Native SVG icon size (matches viewBox)
    public static let iconSize: CGFloat = 16
}
