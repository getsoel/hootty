import Foundation

@Observable
public final class ThemeManager {
    private let configFile: ConfigFile

    public var selectedFlavor: CatppuccinFlavor {
        didSet {
            configFile.set("theme", value: "catppuccin-\(selectedFlavor.rawValue)")
            configFile.save()
        }
    }

    public private(set) var theme: TerminalTheme

    /// Set the resolved theme read back from ghostty config.
    /// Called after ghostty_config_get() resolves the theme colors.
    public func setResolvedTheme(_ theme: TerminalTheme) {
        self.theme = theme
    }

    public init(configFile: ConfigFile) {
        self.configFile = configFile
        let saved = configFile.get("theme")
            .flatMap(CatppuccinFlavor.from(themeName:)) ?? .mocha
        self.selectedFlavor = saved
        self.theme = .catppuccin(saved)
    }
}
