import Testing
import Foundation
@testable import HoottyCore

@Suite struct ThemeManagerTests {
    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
    }

    private func makeTempThemesDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-themes-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Write fallback theme so ThemeManager can parse it
        try! ThemeCatalog.fallbackThemeContent.write(
            to: dir.appendingPathComponent(ThemeCatalog.fallbackThemeName),
            atomically: true, encoding: .utf8
        )
        return dir
    }

    @Test func defaultThemeIsCatppuccinMocha() {
        let configFile = ConfigFile(fileURL: tempFileURL())
        let catalog = ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        #expect(manager.selectedThemeName == "Catppuccin Mocha")
    }

    @Test func setResolvedThemeUpdatesTheme() {
        let configFile = ConfigFile(fileURL: tempFileURL())
        let catalog = ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        let otherTheme = TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)!
        manager.setResolvedTheme(otherTheme)
        #expect(manager.theme == otherTheme)
    }

    @Test func selectedThemeNamePersistsToConfigFile() {
        let url = tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        let catalog = ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        manager.selectedThemeName = "Dracula"

        let configFile2 = ConfigFile(fileURL: url)
        #expect(configFile2.get("theme") == "Dracula")
    }

    @Test func selectedThemeNameLoadsFromConfigFile() {
        let dir = makeTempThemesDir()
        // Write a second theme
        try! ThemeCatalog.fallbackThemeContent.write(
            to: dir.appendingPathComponent("Dracula"),
            atomically: true, encoding: .utf8
        )

        let url = tempFileURL()
        let configFile1 = ConfigFile(fileURL: url)
        configFile1.set("theme", value: "Dracula")
        configFile1.save()

        let configFile2 = ConfigFile(fileURL: url)
        let catalog = ThemeCatalog(themesDirectory: dir)
        let manager = ThemeManager(configFile: configFile2, themeCatalog: catalog)
        #expect(manager.selectedThemeName == "Dracula")
    }

    @Test func changingThemeNameDoesNotAutoUpdateTheme() {
        let configFile = ConfigFile(fileURL: tempFileURL())
        let catalog = ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        let initialTheme = manager.theme
        manager.selectedThemeName = "Something Else"
        // Theme should NOT change automatically — it's set via setResolvedTheme() after ghostty resolves
        #expect(manager.theme == initialTheme)
    }

    @Test func migratesOldHyphenatedNames() {
        #expect(ThemeManager.migrateThemeName("catppuccin-mocha") == "Catppuccin Mocha")
        #expect(ThemeManager.migrateThemeName("catppuccin-latte") == "Catppuccin Latte")
        #expect(ThemeManager.migrateThemeName("catppuccin-frappe") == "Catppuccin Frappe")
        #expect(ThemeManager.migrateThemeName("catppuccin-macchiato") == "Catppuccin Macchiato")
    }

    @Test func nonCatppuccinNamesPassThrough() {
        #expect(ThemeManager.migrateThemeName("Dracula") == "Dracula")
        #expect(ThemeManager.migrateThemeName("Tokyo Night") == "Tokyo Night")
    }

    @Test func migratesOldConfigOnInit() {
        let url = tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        configFile.set("theme", value: "catppuccin-latte")
        configFile.save()

        let configFile2 = ConfigFile(fileURL: url)
        let dir = makeTempThemesDir()
        // Write Catppuccin Latte theme file
        try! ThemeCatalog.fallbackThemeContent.write(
            to: dir.appendingPathComponent("Catppuccin Latte"),
            atomically: true, encoding: .utf8
        )
        let catalog = ThemeCatalog(themesDirectory: dir)
        let manager = ThemeManager(configFile: configFile2, themeCatalog: catalog)
        #expect(manager.selectedThemeName == "Catppuccin Latte")
    }
}
