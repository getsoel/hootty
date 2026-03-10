import Testing
import Foundation
@testable import HoottyCore

@Suite struct ThemeManagerTests {
    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
    }

    @Test func defaultFlavorIsMocha() {
        let configFile = ConfigFile(fileURL: tempFileURL())
        let manager = ThemeManager(configFile: configFile)
        #expect(manager.selectedFlavor == .mocha)
    }

    @Test func setResolvedThemeUpdatesTheme() {
        let configFile = ConfigFile(fileURL: tempFileURL())
        let manager = ThemeManager(configFile: configFile)
        let latteTheme = TerminalTheme.catppuccin(.latte)
        manager.setResolvedTheme(latteTheme)
        #expect(manager.theme == latteTheme)
    }

    @Test func selectedFlavorPersistsToConfigFile() {
        let url = tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        let manager = ThemeManager(configFile: configFile)
        manager.selectedFlavor = .frappe

        let configFile2 = ConfigFile(fileURL: url)
        #expect(configFile2.get("theme") == "catppuccin-frappe")
    }

    @Test func selectedFlavorLoadsFromConfigFile() {
        let url = tempFileURL()
        let configFile1 = ConfigFile(fileURL: url)
        configFile1.set("theme", value: "catppuccin-latte")
        configFile1.save()

        let configFile2 = ConfigFile(fileURL: url)
        let manager = ThemeManager(configFile: configFile2)
        #expect(manager.selectedFlavor == .latte)
    }

    @Test func changingFlavorDoesNotAutoUpdateTheme() {
        let configFile = ConfigFile(fileURL: tempFileURL())
        let manager = ThemeManager(configFile: configFile)
        let initialTheme = manager.theme
        manager.selectedFlavor = .latte
        // Theme should NOT change automatically — it's set via setResolvedTheme() after ghostty resolves
        #expect(manager.theme == initialTheme)
    }
}
