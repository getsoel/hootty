import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct ThemeManagerTests {
    private func makeTempThemesDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-themes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Write fallback theme so ThemeManager can parse it
        try ThemeCatalog.fallbackThemeContent.write(
            to: dir.appendingPathComponent(ThemeCatalog.fallbackThemeName),
            atomically: true, encoding: .utf8
        )
        return dir
    }

    @Test func defaultThemeIsCatppuccinMocha() throws {
        let configFile = ConfigFile(fileURL: TestHelpers.tempFileURL())
        let catalog = try ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        #expect(manager.selectedThemeName == "Catppuccin Mocha")
    }

    @Test func setResolvedThemeUpdatesTheme() throws {
        let configFile = ConfigFile(fileURL: TestHelpers.tempFileURL())
        let catalog = try ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        let otherTheme = try #require(TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent))
        manager.setResolvedTheme(otherTheme)
        #expect(manager.theme == otherTheme)
    }

    @Test func selectedThemeNamePersistsToConfigFile() throws {
        let url = TestHelpers.tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        let catalog = try ThemeCatalog(themesDirectory: makeTempThemesDir())
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        manager.selectedThemeName = "Dracula"

        let configFile2 = ConfigFile(fileURL: url)
        #expect(configFile2.get("theme") == "Dracula")
    }

    @Test func selectedThemeNameLoadsFromConfigFile() throws {
        let dir = try makeTempThemesDir()
        // Write a second theme
        try ThemeCatalog.fallbackThemeContent.write(
            to: dir.appendingPathComponent("Dracula"),
            atomically: true, encoding: .utf8
        )

        let url = TestHelpers.tempFileURL()
        let configFile1 = ConfigFile(fileURL: url)
        configFile1.set("theme", value: "Dracula")
        configFile1.save()

        let configFile2 = ConfigFile(fileURL: url)
        let catalog = ThemeCatalog(themesDirectory: dir)
        let manager = ThemeManager(configFile: configFile2, themeCatalog: catalog)
        #expect(manager.selectedThemeName == "Dracula")
    }

    @Test func changingThemeNameDoesNotAutoUpdateTheme() throws {
        let configFile = ConfigFile(fileURL: TestHelpers.tempFileURL())
        let catalog = try ThemeCatalog(themesDirectory: makeTempThemesDir())
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

    @Test func migratesOldConfigOnInit() throws {
        let url = TestHelpers.tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        configFile.set("theme", value: "catppuccin-latte")
        configFile.save()

        let configFile2 = ConfigFile(fileURL: url)
        let dir = try makeTempThemesDir()
        // Write Catppuccin Latte theme file
        try ThemeCatalog.fallbackThemeContent.write(
            to: dir.appendingPathComponent("Catppuccin Latte"),
            atomically: true, encoding: .utf8
        )
        let catalog = ThemeCatalog(themesDirectory: dir)
        let manager = ThemeManager(configFile: configFile2, themeCatalog: catalog)
        #expect(manager.selectedThemeName == "Catppuccin Latte")
    }
}
