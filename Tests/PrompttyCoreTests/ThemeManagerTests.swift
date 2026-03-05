import Testing
import Foundation
@testable import PrompttyCore

@Suite(.serialized) struct ThemeManagerTests {
    init() {
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
    }

    @Test func defaultFlavorIsMocha() {
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
        let manager = ThemeManager()
        #expect(manager.selectedFlavor == .mocha)
    }

    @Test func themeReturnsCorrectThemeForEachFlavor() {
        let manager = ThemeManager()
        for flavor in CatppuccinFlavor.allCases {
            manager.selectedFlavor = flavor
            let expected = TerminalTheme.catppuccin(flavor)
            #expect(manager.theme == expected)
        }
    }
}
