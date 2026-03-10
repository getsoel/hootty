import Testing
import Foundation
@testable import HoottyCore

@Suite struct ThemeCatalogTests {
    private func makeTempThemesDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-themes-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let sampleThemeContent = """
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

    @Test func discoversThemeFiles() {
        let dir = makeTempThemesDir()
        try! "theme1".write(to: dir.appendingPathComponent("Alpha Theme"), atomically: true, encoding: .utf8)
        try! "theme2".write(to: dir.appendingPathComponent("Beta Theme"), atomically: true, encoding: .utf8)
        try! "theme3".write(to: dir.appendingPathComponent("Catppuccin Mocha"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        #expect(catalog.availableThemes.count == 3)
        #expect(catalog.availableThemes[0] == "Alpha Theme")
        #expect(catalog.availableThemes[1] == "Beta Theme")
        #expect(catalog.availableThemes[2] == "Catppuccin Mocha")
    }

    @Test func themeContentReadsCorrectly() {
        let dir = makeTempThemesDir()
        try! sampleThemeContent.write(to: dir.appendingPathComponent("Test Theme"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        let content = catalog.themeContent(for: "Test Theme")
        #expect(content != nil)
        #expect(content!.contains("background = #1e1e2e"))
    }

    @Test func missingThemeReturnsNil() {
        let dir = makeTempThemesDir()
        let catalog = ThemeCatalog(themesDirectory: dir)
        #expect(catalog.themeContent(for: "Nonexistent Theme") == nil)
    }

    @Test func excludesDotFiles() {
        let dir = makeTempThemesDir()
        try! "hidden".write(to: dir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try! "visible".write(to: dir.appendingPathComponent("Dracula"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        #expect(catalog.availableThemes == ["Dracula"])
    }

    @Test func nilDirectoryGivesEmptyCatalog() {
        let catalog = ThemeCatalog(themesDirectory: nil)
        #expect(catalog.availableThemes.isEmpty)
        #expect(catalog.themeContent(for: "anything") == nil)
    }

    @Test func fallbackThemeContentParses() {
        let theme = TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)
        #expect(theme != nil)
        #expect(theme!.palette.count == 16)
    }

    // MARK: - Theme Preview Tests

    @Test func loadPreviewsPopulatesCache() {
        let dir = makeTempThemesDir()
        try! sampleThemeContent.write(to: dir.appendingPathComponent("Alpha"), atomically: true, encoding: .utf8)
        try! sampleThemeContent.write(to: dir.appendingPathComponent("Beta"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        #expect(catalog.themePreviews.isEmpty)

        catalog.loadPreviews()
        #expect(catalog.themePreviews.count == 2)
        #expect(catalog.themePreviews[0].name == "Alpha")
        #expect(catalog.themePreviews[1].name == "Beta")
    }

    @Test func loadPreviewsCachesResults() {
        let dir = makeTempThemesDir()
        try! sampleThemeContent.write(to: dir.appendingPathComponent("Theme1"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        catalog.loadPreviews()
        #expect(catalog.themePreviews.count == 1)

        // Add another file — loadPreviews should return cached results
        try! sampleThemeContent.write(to: dir.appendingPathComponent("Theme2"), atomically: true, encoding: .utf8)
        catalog.loadPreviews()
        #expect(catalog.themePreviews.count == 1)
    }

    @Test func loadPreviewsSkipsInvalidFiles() {
        let dir = makeTempThemesDir()
        try! sampleThemeContent.write(to: dir.appendingPathComponent("ValidTheme"), atomically: true, encoding: .utf8)
        try! "not a valid theme file".write(to: dir.appendingPathComponent("InvalidTheme"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        catalog.loadPreviews()
        #expect(catalog.themePreviews.count == 1)
        #expect(catalog.themePreviews[0].name == "ValidTheme")
    }

    @Test func previewIsLightFlag() {
        let dir = makeTempThemesDir()
        // Dark theme (background #1e1e2e)
        try! sampleThemeContent.write(to: dir.appendingPathComponent("DarkTheme"), atomically: true, encoding: .utf8)
        // Light theme
        let lightContent = sampleThemeContent.replacingOccurrences(of: "background = #1e1e2e", with: "background = #eff1f5")
        try! lightContent.write(to: dir.appendingPathComponent("LightTheme"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        catalog.loadPreviews()
        let dark = catalog.themePreviews.first { $0.name == "DarkTheme" }
        let light = catalog.themePreviews.first { $0.name == "LightTheme" }
        #expect(dark?.isLight == false)
        #expect(light?.isLight == true)
    }

    @Test func previewHas16PaletteColors() {
        let dir = makeTempThemesDir()
        try! sampleThemeContent.write(to: dir.appendingPathComponent("TestTheme"), atomically: true, encoding: .utf8)

        let catalog = ThemeCatalog(themesDirectory: dir)
        catalog.loadPreviews()
        #expect(catalog.themePreviews[0].palette.count == 16)
    }
}
