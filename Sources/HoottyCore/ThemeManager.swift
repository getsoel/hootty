import Foundation

@MainActor
@Observable
public final class ThemeManager {
    private var configFile: ConfigFile
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

    /// Swap to a different profile's config file and re-read the theme.
    public func updateConfigFile(_ newConfigFile: ConfigFile) {
        configFile = newConfigFile
        let raw = newConfigFile.get("theme") ?? ThemeCatalog.fallbackThemeName
        let migrated = Self.migrateThemeName(raw)
        selectedThemeName = migrated
        let content = themeCatalog.themeContent(for: migrated) ?? ThemeCatalog.fallbackThemeContent
        theme = TerminalTheme.parse(ghosttyThemeContent: content)
            ?? TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)!
    }

    /// Migrate old hyphenated catppuccin theme names to the tarball filename format.
    static func migrateThemeName(_ name: String) -> String {
        let migrations = [
            "catppuccin-mocha": "Catppuccin Mocha",
            "catppuccin-latte": "Catppuccin Latte",
            "catppuccin-frappe": "Catppuccin Frappe",
            "catppuccin-macchiato": "Catppuccin Macchiato"
        ]
        return migrations[name] ?? name
    }
}
