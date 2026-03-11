import AppKit

/// Lightweight preview data for a theme (name + key colors).
public struct ThemePreview: Identifiable, Sendable {
    public let name: String
    public let background: NSColor
    public let foreground: NSColor
    /// 16 ANSI palette colors (indices 0-15).
    public let palette: [NSColor]
    public let isLight: Bool

    public var id: String { name }
}

@Observable
public final class ThemeCatalog {
    /// Sorted list of available theme filenames.
    public let availableThemes: [String]
    private let themesDirectory: URL?

    /// Cached theme previews, populated by `loadPreviews()`.
    public private(set) var themePreviews: [ThemePreview] = []
    private var previewsLoaded = false

    public init(themesDirectory: URL?) {
        self.themesDirectory = themesDirectory
        if let dir = themesDirectory,
           let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            self.availableThemes = files
                .filter { !$0.hasPrefix(".") }
                .sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        } else {
            self.availableThemes = []
        }
    }

    /// Parse all theme files into preview structs. Cached after first call.
    public func loadPreviews() {
        guard !previewsLoaded else { return }
        previewsLoaded = true

        var previews: [ThemePreview] = []
        for name in availableThemes {
            guard let content = themeContent(for: name),
                  let theme = TerminalTheme.parse(ghosttyThemeContent: content) else { continue }
            previews.append(ThemePreview(
                name: name,
                background: theme.background,
                foreground: theme.foreground,
                palette: theme.palette,
                isLight: theme.isLight
            ))
        }
        let pinned = previews.filter { $0.name.hasPrefix("Catppuccin") }
        let rest = previews.filter { !$0.name.hasPrefix("Catppuccin") }
        themePreviews = pinned + rest
    }

    /// Read the raw theme file content for a given theme name.
    public func themeContent(for name: String) -> String? {
        guard let dir = themesDirectory else { return nil }
        return try? String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    /// Hardcoded fallback theme name when the themes directory is missing.
    public static let fallbackThemeName = "Catppuccin Mocha"

    /// Hardcoded fallback Catppuccin Mocha content (with # prefix, matching tarball format).
    public static let fallbackThemeContent = """
        background = #1e1e2e
        foreground = #cdd6f4
        cursor-color = #f5e0dc
        selection-background = #585b70
        selection-foreground = #cdd6f4
        palette = 0=#45475a
        palette = 1=#f38ba8
        palette = 2=#a6e3a1
        palette = 3=#f9e2af
        palette = 4=#89b4fa
        palette = 5=#f5c2e7
        palette = 6=#94e2d5
        palette = 7=#a6adc8
        palette = 8=#585b70
        palette = 9=#f37799
        palette = 10=#89d88b
        palette = 11=#ebd391
        palette = 12=#74a8fc
        palette = 13=#f2aede
        palette = 14=#6bd7ca
        palette = 15=#bac2de
        """
}
