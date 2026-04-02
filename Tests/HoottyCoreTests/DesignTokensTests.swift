import AppKit
import Testing
@testable import HoottyCore

struct DesignTokensTests {
    // MARK: - elementSelectedText always uses foreground (accent-tinted backgrounds)

    @Test("elementSelectedText is always foreground regardless of theme")
    func selectedTextAlwaysForeground() {
        // Dark theme
        let dark = TerminalTheme(
            palette: (0 ..< 16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0x1E1E2E),
            foreground: TerminalTheme.hex(0xCDD6F4),
            cursorColor: NSColor.white,
            selectionBackground: TerminalTheme.hex(0x45475A),
            selectionForeground: TerminalTheme.hex(0xCDD6F4)
        )
        #expect(DesignTokens.from(dark).elementSelectedText == dark.foreground)

        // Light theme
        let light = TerminalTheme(
            palette: (0 ..< 16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0xEFF1F5),
            foreground: TerminalTheme.hex(0x4C4F69),
            cursorColor: NSColor.black,
            selectionBackground: TerminalTheme.hex(0xBCC0CC),
            selectionForeground: TerminalTheme.hex(0x4C4F69)
        )
        #expect(DesignTokens.from(light).elementSelectedText == light.foreground)
    }

    @Test("elementSelected uses neutral tint from palette[7]")
    func selectedUsesNeutralTint() throws {
        let subtext = TerminalTheme.hex(0x6C7086)
        let theme = TerminalTheme(
            palette: (0 ..< 16).map { i in i == 7 ? subtext : NSColor.gray },
            background: TerminalTheme.hex(0xEFF1F5),
            foreground: TerminalTheme.hex(0x4C4F69),
            cursorColor: NSColor.black,
            selectionBackground: TerminalTheme.hex(0xACB0BE),
            selectionForeground: TerminalTheme.hex(0x4C4F69)
        )
        let tokens = DesignTokens.from(theme)
        // elementSelected should be palette[7] (subtext) at 15% opacity
        let selected = try #require(tokens.elementSelected.usingColorSpace(.sRGB))
        let neutral = try #require(theme.palette[7].usingColorSpace(.sRGB))
        #expect(abs(selected.redComponent - neutral.redComponent) < 0.01)
        #expect(abs(selected.greenComponent - neutral.greenComponent) < 0.01)
        #expect(abs(selected.blueComponent - neutral.blueComponent) < 0.01)
        #expect(abs(selected.alphaComponent - 0.15) < 0.01)
    }
}
