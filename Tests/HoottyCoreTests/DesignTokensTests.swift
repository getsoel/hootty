import Testing
@testable import HoottyCore
import AppKit

@Suite("DesignTokens")
struct DesignTokensTests {
    // MARK: - elementSelectedText always uses foreground (accent-tinted backgrounds)

    @Test("elementSelectedText is always foreground regardless of theme")
    func selectedTextAlwaysForeground() {
        // Dark theme
        let dark = TerminalTheme(
            palette: (0..<16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0x1e1e2e),
            foreground: TerminalTheme.hex(0xcdd6f4),
            cursorColor: NSColor.white,
            selectionBackground: TerminalTheme.hex(0x45475a),
            selectionForeground: TerminalTheme.hex(0xcdd6f4)
        )
        #expect(DesignTokens.from(dark).elementSelectedText == dark.foreground)

        // Light theme
        let light = TerminalTheme(
            palette: (0..<16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0xeff1f5),
            foreground: TerminalTheme.hex(0x4c4f69),
            cursorColor: NSColor.black,
            selectionBackground: TerminalTheme.hex(0xbcc0cc),
            selectionForeground: TerminalTheme.hex(0x4c4f69)
        )
        #expect(DesignTokens.from(light).elementSelectedText == light.foreground)
    }

    @Test("elementSelected uses accent tint from palette[4]")
    func selectedUsesAccentTint() {
        let theme = TerminalTheme(
            palette: (0..<16).map { i in i == 4 ? TerminalTheme.hex(0x1e66f5) : NSColor.gray },
            background: TerminalTheme.hex(0xeff1f5),
            foreground: TerminalTheme.hex(0x4c4f69),
            cursorColor: NSColor.black,
            selectionBackground: TerminalTheme.hex(0xacb0be),
            selectionForeground: TerminalTheme.hex(0x4c4f69)
        )
        let tokens = DesignTokens.from(theme)
        // elementSelected should be palette[4] at 15% opacity, not selectionBackground
        let selected = tokens.elementSelected.usingColorSpace(.sRGB)!
        let accent = theme.palette[4].usingColorSpace(.sRGB)!
        #expect(abs(selected.redComponent - accent.redComponent) < 0.01)
        #expect(abs(selected.greenComponent - accent.greenComponent) < 0.01)
        #expect(abs(selected.blueComponent - accent.blueComponent) < 0.01)
        #expect(abs(selected.alphaComponent - 0.15) < 0.01)
    }
}
