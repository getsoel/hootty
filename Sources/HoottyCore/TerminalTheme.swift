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
        case .frappe:    return "Frappé"
        case .macchiato: return "Macchiato"
        case .mocha:     return "Mocha"
        }
    }
}

public struct TerminalTheme: Equatable {
    public let palette: [NSColor]        // 16 ANSI colors (0-15)
    public let background: NSColor
    public let foreground: NSColor
    public let cursorColor: NSColor
    public let selectionBackground: NSColor
    public let selectionForeground: NSColor
    public let mantle: NSColor                   // darker-than-background chrome color
    public let sidebarSurface: NSColor        // selected row bg / divider
    public let sidebarTextSecondary: NSColor   // subdued text
    public let sidebarRunningDot: NSColor      // green status dot
    public let sidebarStoppedDot: NSColor      // gray status dot
    public var attentionColor: NSColor { palette[3] }  // yellow (ANSI color 3)

    public static func == (lhs: TerminalTheme, rhs: TerminalTheme) -> Bool {
        lhs.palette == rhs.palette
            && lhs.background == rhs.background
            && lhs.foreground == rhs.foreground
            && lhs.cursorColor == rhs.cursorColor
            && lhs.selectionBackground == rhs.selectionBackground
            && lhs.selectionForeground == rhs.selectionForeground
            && lhs.mantle == rhs.mantle
            && lhs.sidebarSurface == rhs.sidebarSurface
            && lhs.sidebarTextSecondary == rhs.sidebarTextSecondary
            && lhs.sidebarRunningDot == rhs.sidebarRunningDot
            && lhs.sidebarStoppedDot == rhs.sidebarStoppedDot
    }

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
                selectionForeground: hex(0xcdd6f4),
                mantle: hex(0x181825),                // mantle
                sidebarSurface: hex(0x313244),       // surface0
                sidebarTextSecondary: hex(0xa6adc8),  // subtext0
                sidebarRunningDot: hex(0xa6e3a1),     // green
                sidebarStoppedDot: hex(0x6c7086)      // overlay0
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
                selectionForeground: hex(0xcad3f5),
                mantle: hex(0x1e2030),                // mantle
                sidebarSurface: hex(0x363a4f),       // surface0
                sidebarTextSecondary: hex(0xa5adcb),  // subtext0
                sidebarRunningDot: hex(0xa6da95),     // green
                sidebarStoppedDot: hex(0x6e738d)      // overlay0
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
                selectionForeground: hex(0xc6d0f5),
                mantle: hex(0x292c3c),                // mantle
                sidebarSurface: hex(0x414559),       // surface0
                sidebarTextSecondary: hex(0xa5adce),  // subtext0
                sidebarRunningDot: hex(0xa6d189),     // green
                sidebarStoppedDot: hex(0x737994)      // overlay0
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
                selectionForeground: hex(0x4c4f69),
                mantle: hex(0xe6e9ef),                // mantle
                sidebarSurface: hex(0xccd0da),       // surface0
                sidebarTextSecondary: hex(0x6c6f85),  // subtext0
                sidebarRunningDot: hex(0x40a02b),     // green
                sidebarStoppedDot: hex(0x9ca0b0)      // overlay0
            )
        }
    }

    /// Generate a ghostty config string with all terminal color settings.
    public func generateGhosttyConfig() -> String {
        var lines: [String] = []
        lines.append("background = \(Self.hexString(background))")
        lines.append("foreground = \(Self.hexString(foreground))")
        lines.append("cursor-color = \(Self.hexString(cursorColor))")
        lines.append("selection-background = \(Self.hexString(selectionBackground))")
        lines.append("selection-foreground = \(Self.hexString(selectionForeground))")
        for (i, color) in palette.enumerated() {
            lines.append("palette = \(i)=#\(Self.hexString(color))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Convert an NSColor to a 6-digit hex string (e.g. "1e1e2e").
    static func hexString(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "%02x%02x%02x", r, g, b)
    }

    static func hex(_ value: UInt32) -> NSColor {
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
