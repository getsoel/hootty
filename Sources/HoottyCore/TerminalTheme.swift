import AppKit

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

    /// Parse a ghostty theme config string into a TerminalTheme.
    /// Handles: background, foreground, cursor-color, selection-background, selection-foreground,
    /// palette = N=RRGGBB. Skips blank lines and # comments. Returns nil if required fields missing
    /// or palette incomplete (< 16 entries).
    public static func parse(ghosttyThemeContent content: String) -> TerminalTheme? {
        var bg: NSColor?
        var fg: NSColor?
        var cursor: NSColor?
        var selBg: NSColor?
        var selFg: NSColor?
        var palette = [Int: NSColor]()

        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<eqIdx].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: eqIdx)...].trimmingCharacters(in: .whitespaces)

            switch key {
            case "background":            bg = hex(value)
            case "foreground":            fg = hex(value)
            case "cursor-color":          cursor = hex(value)
            case "selection-background":  selBg = hex(value)
            case "selection-foreground":  selFg = hex(value)
            case "palette":
                // format: "N=rrggbb" or "N=#rrggbb"
                guard let sepIdx = value.firstIndex(of: "=") else { continue }
                guard let idx = Int(value[value.startIndex..<sepIdx]),
                      idx >= 0, idx < 16 else { continue }
                guard let color = hex(String(value[value.index(after: sepIdx)...])) else { continue }
                palette[idx] = color
            default:
                break
            }
        }

        guard let bg, let fg, let cursor, let selBg, let selFg else { return nil }
        guard palette.count >= 16 else { return nil }

        let sortedPalette = (0..<16).compactMap { palette[$0] }
        guard sortedPalette.count == 16 else { return nil }

        return TerminalTheme(
            palette: sortedPalette,
            background: bg,
            foreground: fg,
            cursorColor: cursor,
            selectionBackground: selBg,
            selectionForeground: selFg
        )
    }

    /// Parse a hex color string into an NSColor. Accepts both "1e1e2e" and "#1e1e2e".
    public static func hex(_ string: String) -> NSColor? {
        let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        return hex(value)
    }

    static func hex(_ value: UInt32) -> NSColor {
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// Convert an NSColor to a 6-char hex string (e.g. "1e1e2e").
    public static func hexString(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "%02x%02x%02x", r, g, b)
    }
}
