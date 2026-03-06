import Testing
import AppKit
@testable import HoottyCore

@Suite struct TerminalThemeTests {
    @Test func eachFlavorHas16AnsiColors() {
        for flavor in CatppuccinFlavor.allCases {
            let theme = TerminalTheme.catppuccin(flavor)
            #expect(theme.palette.count == 16, "Expected 16 colors for \(flavor)")
        }
    }

    @Test func hexConvertsCorrectly() {
        // Mocha background: 0x1e1e2e → r=30, g=30, b=46
        let color = TerminalTheme.hex(0x1e1e2e)
        #expect(abs(color.redComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color.greenComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color.blueComponent - 46.0 / 255.0) < 0.001)
    }

    @Test func allFlavorsAreDistinct() {
        let themes = CatppuccinFlavor.allCases.map { TerminalTheme.catppuccin($0) }
        for i in 0..<themes.count {
            for j in (i + 1)..<themes.count {
                #expect(themes[i] != themes[j], "Flavors \(i) and \(j) should be distinct")
            }
        }
    }

    @Test func themeHasAllRequiredColors() {
        for flavor in CatppuccinFlavor.allCases {
            let theme = TerminalTheme.catppuccin(flavor)
            // These just verify the properties exist and are non-nil NSColors
            #expect(theme.background.alphaComponent == 1.0)
            #expect(theme.foreground.alphaComponent == 1.0)
            #expect(theme.cursorColor.alphaComponent == 1.0)
            #expect(theme.selectionBackground.alphaComponent == 1.0)
            #expect(theme.crust.alphaComponent == 1.0)
        }
    }
}
