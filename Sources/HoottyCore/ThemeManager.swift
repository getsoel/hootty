import Foundation

@Observable
public final class ThemeManager {
    private let configFile: ConfigFile
    public let themeCatalog: ThemeCatalog

    public var selectedThemeName: String {
        didSet {
            configFile.set("theme", value: selectedThemeName)
            configFile.save()
        }
    }

    public private(set) var theme: TerminalTheme

    /// Set the resolved theme read back from ghostty config.
    /// Called after ghostty_config_get() resolves the theme colors.
    public func setResolvedTheme(_ theme: TerminalTheme) {
        self.theme = theme
    }

    public init(configFile: ConfigFile, themeCatalog: ThemeCatalog) {
        self.configFile = configFile
        self.themeCatalog = themeCatalog

        // Migrate old hyphenated names to tarball filenames
        let raw = configFile.get("theme") ?? ThemeCatalog.fallbackThemeName
        let migrated = Self.migrateThemeName(raw)
        self.selectedThemeName = migrated

        // Parse theme content for initial display
        let content = themeCatalog.themeContent(for: migrated) ?? ThemeCatalog.fallbackThemeContent
        self.theme = TerminalTheme.parse(ghosttyThemeContent: content)
            ?? TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)!
    }

    /// Migrate old hyphenated catppuccin theme names to the tarball filename format.
    static func migrateThemeName(_ name: String) -> String {
        let migrations = [
            "catppuccin-mocha": "Catppuccin Mocha",
            "catppuccin-latte": "Catppuccin Latte",
            "catppuccin-frappe": "Catppuccin Frappe",
            "catppuccin-macchiato": "Catppuccin Macchiato",
        ]
        return migrations[name] ?? name
    }
}
