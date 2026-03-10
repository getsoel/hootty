import AppKit

public enum CatppuccinFlavor: String, CaseIterable {
    case latte
    case frappe
    case macchiato
    case mocha

    public var isLight: Bool { self == .latte }

    public var displayName: String {
        switch self {
        case .latte:     return "Latte"
        case .frappe:    return "Frapp\u{00e9}"
        case .macchiato: return "Macchiato"
        case .mocha:     return "Mocha"
        }
    }

    /// Ghostty built-in theme name for this flavor.
    public var ghosttyThemeName: String {
        "catppuccin-\(rawValue)"
    }

    /// Parse a ghostty theme name like "catppuccin-mocha" into a flavor.
    public static func from(themeName name: String) -> CatppuccinFlavor? {
        guard name.hasPrefix("catppuccin-") else { return nil }
        return CatppuccinFlavor(rawValue: String(name.dropFirst("catppuccin-".count)))
    }
}

public struct TerminalTheme: Equatable {
    public let palette: [NSColor]           // 16 ANSI colors (0-15)
    public let background: NSColor
    public let foreground: NSColor
    public let cursorColor: NSColor
    public let selectionBackground: NSColor
    public let selectionForeground: NSColor

    /// Whether this is a light theme (background luminance > 0.5).
    public var isLight: Bool {
        let c = background.usingColorSpace(.sRGB) ?? background
        let luminance = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return luminance > 0.5
    }

    public init(
        palette: [NSColor],
        background: NSColor,
        foreground: NSColor,
        cursorColor: NSColor,
        selectionBackground: NSColor,
        selectionForeground: NSColor
    ) {
        self.palette = palette
        self.background = background
        self.foreground = foreground
        self.cursorColor = cursorColor
        self.selectionBackground = selectionBackground
        self.selectionForeground = selectionForeground
    }

    public static func == (lhs: TerminalTheme, rhs: TerminalTheme) -> Bool {
        lhs.palette == rhs.palette
            && lhs.background == rhs.background
            && lhs.foreground == rhs.foreground
            && lhs.cursorColor == rhs.cursorColor
            && lhs.selectionBackground == rhs.selectionBackground
            && lhs.selectionForeground == rhs.selectionForeground
    }

    /// Fallback theme from hardcoded Catppuccin palette values.
    /// Used only when ghostty_config_get() fails to read back resolved colors.
    public static func catppuccin(_ flavor: CatppuccinFlavor) -> TerminalTheme {
        switch flavor {
        case .mocha:
            return TerminalTheme(
                palette: [
                    hex(0x45475a), hex(0xf38ba8), hex(0xa6e3a1), hex(0xf9e2af),
                    hex(0x89b4fa), hex(0xf5c2e7), hex(0x94e2d5), hex(0xa6adc8),
                    hex(0x585b70), hex(0xf37799), hex(0x89d88b), hex(0xebd391),
                    hex(0x74a8fc), hex(0xf2aede), hex(0x6bd7ca), hex(0xbac2de),
                ],
                background: hex(0x1e1e2e),
                foreground: hex(0xcdd6f4),
                cursorColor: hex(0xf5e0dc),
                selectionBackground: hex(0x585b70),
                selectionForeground: hex(0xcdd6f4)
            )
        case .macchiato:
            return TerminalTheme(
                palette: [
                    hex(0x494d64), hex(0xed8796), hex(0xa6da95), hex(0xeed49f),
                    hex(0x8aadf4), hex(0xf5bde6), hex(0x8bd5ca), hex(0xa5adcb),
                    hex(0x5b6078), hex(0xec7486), hex(0x8ccf7f), hex(0xe1c682),
                    hex(0x78a1f6), hex(0xf2a9dd), hex(0x63cbc0), hex(0xb8c0e0),
                ],
                background: hex(0x24273a),
                foreground: hex(0xcad3f5),
                cursorColor: hex(0xf4dbd6),
                selectionBackground: hex(0x5b6078),
                selectionForeground: hex(0xcad3f5)
            )
        case .frappe:
            return TerminalTheme(
                palette: [
                    hex(0x51576d), hex(0xe78284), hex(0xa6d189), hex(0xe5c890),
                    hex(0x8caaee), hex(0xf4b8e4), hex(0x81c8be), hex(0xa5adce),
                    hex(0x626880), hex(0xe67172), hex(0x8ec772), hex(0xd9ba73),
                    hex(0x7b9ef0), hex(0xf2a4db), hex(0x5abfb5), hex(0xb5bfe2),
                ],
                background: hex(0x303446),
                foreground: hex(0xc6d0f5),
                cursorColor: hex(0xf2d5cf),
                selectionBackground: hex(0x626880),
                selectionForeground: hex(0xc6d0f5)
            )
        case .latte:
            return TerminalTheme(
                palette: [
                    hex(0x5c5f77), hex(0xd20f39), hex(0x40a02b), hex(0xdf8e1d),
                    hex(0x1e66f5), hex(0xea76cb), hex(0x179299), hex(0xacb0be),
                    hex(0x6c6f85), hex(0xde293e), hex(0x49af3d), hex(0xeea02d),
                    hex(0x456eff), hex(0xfe85d8), hex(0x2d9fa8), hex(0xbcc0cc),
                ],
                background: hex(0xeff1f5),
                foreground: hex(0x4c4f69),
                cursorColor: hex(0xdc8a78),
                selectionBackground: hex(0xacb0be),
                selectionForeground: hex(0x4c4f69)
            )
        }
    }

    static func hex(_ value: UInt32) -> NSColor {
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
