import Testing
import AppKit
@testable import HoottyCore

@Suite struct TerminalThemeTests {
    @Test func hexConvertsCorrectly() {
        // Mocha background: 0x1e1e2e -> r=30, g=30, b=46
        let color = TerminalTheme.hex(0x1e1e2e)
        #expect(abs(color.redComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color.greenComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color.blueComponent - 46.0 / 255.0) < 0.001)
    }

    @Test func hexStringRoundTrips() {
        let color = TerminalTheme.hex(0x1e1e2e)
        #expect(TerminalTheme.hexString(color) == "1e1e2e")
    }

    @Test func hexFromStringParsesCorrectly() {
        let color = TerminalTheme.hex("1e1e2e")
        #expect(color != nil)
        #expect(abs(color!.redComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color!.greenComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color!.blueComponent - 46.0 / 255.0) < 0.001)
    }

    @Test func hexFromStringRejectsInvalid() {
        #expect(TerminalTheme.hex("zzzzzz") == nil)
        #expect(TerminalTheme.hex("1e1e") == nil)
        #expect(TerminalTheme.hex("") == nil)
    }

    @Test func hexFromStringHandsHashPrefix() {
        let color = TerminalTheme.hex("#1e1e2e")
        #expect(color != nil)
        #expect(abs(color!.redComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color!.greenComponent - 30.0 / 255.0) < 0.001)
        #expect(abs(color!.blueComponent - 46.0 / 255.0) < 0.001)
    }

    @Test func hexFromStringRejectsInvalidWithHash() {
        #expect(TerminalTheme.hex("#zzzzzz") == nil)
        #expect(TerminalTheme.hex("#1e1e") == nil)
        #expect(TerminalTheme.hex("#") == nil)
    }

    @Test func parseValidThemeContent() {
        let content = """
            background = 1e1e2e
            foreground = cdd6f4
            cursor-color = f5e0dc
            selection-background = 585b70
            selection-foreground = cdd6f4
            palette = 0=45475a
            palette = 1=f38ba8
            palette = 2=a6e3a1
            palette = 3=f9e2af
            palette = 4=89b4fa
            palette = 5=f5c2e7
            palette = 6=94e2d5
            palette = 7=a6adc8
            palette = 8=585b70
            palette = 9=f37799
            palette = 10=89d88b
            palette = 11=ebd391
            palette = 12=74a8fc
            palette = 13=f2aede
            palette = 14=6bd7ca
            palette = 15=bac2de
            """
        let theme = TerminalTheme.parse(ghosttyThemeContent: content)
        #expect(theme != nil)
        #expect(theme!.palette.count == 16)
        #expect(TerminalTheme.hexString(theme!.background) == "1e1e2e")
        #expect(TerminalTheme.hexString(theme!.foreground) == "cdd6f4")
        #expect(TerminalTheme.hexString(theme!.cursorColor) == "f5e0dc")
        #expect(TerminalTheme.hexString(theme!.selectionBackground) == "585b70")
        #expect(TerminalTheme.hexString(theme!.selectionForeground) == "cdd6f4")
        #expect(TerminalTheme.hexString(theme!.palette[0]) == "45475a")
        #expect(TerminalTheme.hexString(theme!.palette[15]) == "bac2de")
    }

    @Test func parseValidThemeContentWithHashPrefix() {
        let content = """
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
        let theme = TerminalTheme.parse(ghosttyThemeContent: content)
        #expect(theme != nil)
        #expect(theme!.palette.count == 16)
        #expect(TerminalTheme.hexString(theme!.background) == "1e1e2e")
        #expect(TerminalTheme.hexString(theme!.foreground) == "cdd6f4")
    }

    @Test func parseReturnsNilOnMissingBackground() {
        let content = """
            foreground = cdd6f4
            cursor-color = f5e0dc
            selection-background = 585b70
            selection-foreground = cdd6f4
            palette = 0=45475a
            palette = 1=f38ba8
            palette = 2=a6e3a1
            palette = 3=f9e2af
            palette = 4=89b4fa
            palette = 5=f5c2e7
            palette = 6=94e2d5
            palette = 7=a6adc8
            palette = 8=585b70
            palette = 9=f37799
            palette = 10=89d88b
            palette = 11=ebd391
            palette = 12=74a8fc
            palette = 13=f2aede
            palette = 14=6bd7ca
            palette = 15=bac2de
            """
        #expect(TerminalTheme.parse(ghosttyThemeContent: content) == nil)
    }

    @Test func parseReturnsNilOnIncompletePalette() {
        let content = """
            background = 1e1e2e
            foreground = cdd6f4
            cursor-color = f5e0dc
            selection-background = 585b70
            selection-foreground = cdd6f4
            palette = 0=45475a
            palette = 1=f38ba8
            palette = 2=a6e3a1
            """
        #expect(TerminalTheme.parse(ghosttyThemeContent: content) == nil)
    }

    @Test func parseIgnoresCommentsAndBlankLines() {
        let content = """
            # This is a comment
            background = 1e1e2e

            foreground = cdd6f4
            # Another comment
            cursor-color = f5e0dc
            selection-background = 585b70
            selection-foreground = cdd6f4
            palette = 0=45475a
            palette = 1=f38ba8
            palette = 2=a6e3a1
            palette = 3=f9e2af
            palette = 4=89b4fa
            palette = 5=f5c2e7
            palette = 6=94e2d5
            palette = 7=a6adc8
            palette = 8=585b70
            palette = 9=f37799
            palette = 10=89d88b
            palette = 11=ebd391
            palette = 12=74a8fc
            palette = 13=f2aede
            palette = 14=6bd7ca
            palette = 15=bac2de
            """
        let theme = TerminalTheme.parse(ghosttyThemeContent: content)
        #expect(theme != nil)
        #expect(TerminalTheme.hexString(theme!.background) == "1e1e2e")
    }

    @Test func parseIgnoresUnknownKeys() {
        let content = """
            background = #1e1e2e
            foreground = #cdd6f4
            cursor-color = #f5e0dc
            cursor-text = #1e1e2e
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
        let theme = TerminalTheme.parse(ghosttyThemeContent: content)
        #expect(theme != nil)
    }

    @Test func isLightDetectsLightTheme() {
        // Latte background: eff1f5 (very light)
        let content = """
            background = #eff1f5
            foreground = #4c4f69
            cursor-color = #dc8a78
            selection-background = #acb0be
            selection-foreground = #4c4f69
            palette = 0=#5c5f77
            palette = 1=#d20f39
            palette = 2=#40a02b
            palette = 3=#df8e1d
            palette = 4=#1e66f5
            palette = 5=#ea76cb
            palette = 6=#179299
            palette = 7=#acb0be
            palette = 8=#6c6f85
            palette = 9=#de293e
            palette = 10=#49af3d
            palette = 11=#eea02d
            palette = 12=#456eff
            palette = 13=#fe85d8
            palette = 14=#2d9fa8
            palette = 15=#bcc0cc
            """
        let theme = TerminalTheme.parse(ghosttyThemeContent: content)!
        #expect(theme.isLight)
    }

    @Test func isLightDetectsDarkTheme() {
        // Mocha background: 1e1e2e (very dark)
        let theme = TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)!
        #expect(!theme.isLight)
    }

    @Test func fallbackThemeContentParses() {
        let theme = TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)
        #expect(theme != nil)
        #expect(theme!.palette.count == 16)
        #expect(TerminalTheme.hexString(theme!.background) == "1e1e2e")
    }
}
