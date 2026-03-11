import Testing
@testable import HoottyCore
import AppKit

@Suite("DesignTokens")
struct DesignTokensTests {
    // MARK: - elementSelectedText contrast awareness

    @Test("dark theme with dark selection keeps foreground text")
    func darkSelectionKeepsForeground() {
        // Catppuccin Mocha-like: light foreground on dark selection background
        let theme = TerminalTheme(
            palette: (0..<16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0x1e1e2e),      // dark
            foreground: TerminalTheme.hex(0xcdd6f4),       // light
            cursorColor: NSColor.white,
            selectionBackground: TerminalTheme.hex(0x45475a), // dark
            selectionForeground: TerminalTheme.hex(0xcdd6f4)  // light
        )
        let tokens = DesignTokens.from(theme)
        // Light text on dark selection = high contrast → keep foreground
        #expect(tokens.elementSelectedText == theme.foreground)
    }

    @Test("dark theme with light selection falls back to selectionForeground")
    func lightSelectionFallsBack() {
        // Aardvark Blue-like: light foreground but light selection background
        let theme = TerminalTheme(
            palette: (0..<16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0x1a1a2e),      // dark
            foreground: TerminalTheme.hex(0xc0c0c0),       // light
            cursorColor: NSColor.white,
            selectionBackground: TerminalTheme.hex(0xd0d0d0), // light
            selectionForeground: TerminalTheme.hex(0x000000)  // black
        )
        let tokens = DesignTokens.from(theme)
        // Light text on light selection = low contrast → use selectionForeground
        #expect(tokens.elementSelectedText == theme.selectionForeground)
    }

    @Test("light theme with light selection keeps foreground text")
    func lightThemeLightSelection() {
        // Light theme: dark foreground on light selection = already high contrast
        let theme = TerminalTheme(
            palette: (0..<16).map { _ in NSColor.gray },
            background: TerminalTheme.hex(0xeff1f5),       // light
            foreground: TerminalTheme.hex(0x4c4f69),       // dark
            cursorColor: NSColor.black,
            selectionBackground: TerminalTheme.hex(0xbcc0cc), // light
            selectionForeground: TerminalTheme.hex(0x4c4f69)  // dark
        )
        let tokens = DesignTokens.from(theme)
        // Dark text on light selection = high contrast → keep foreground
        #expect(tokens.elementSelectedText == theme.foreground)
    }
}
