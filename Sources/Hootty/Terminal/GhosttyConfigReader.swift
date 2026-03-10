import AppKit
import CGhostty
import HoottyCore

/// Reads resolved theme colors from a finalized ghostty config via ghostty_config_get().
struct GhosttyConfigReader {
    /// Read resolved theme colors from a finalized ghostty config.
    /// Returns nil if any required color read fails.
    static func readTheme(from config: ghostty_config_t) -> TerminalTheme? {
        guard let background = readColor(from: config, key: "background"),
              let foreground = readColor(from: config, key: "foreground"),
              let cursorColor = readColor(from: config, key: "cursor-color"),
              let selectionBg = readColor(from: config, key: "selection-background"),
              let selectionFg = readColor(from: config, key: "selection-foreground") else {
            Log.ghostty.warning("Failed to read one or more colors from ghostty config")
            return nil
        }

        guard let palette = readPalette(from: config) else {
            Log.ghostty.warning("Failed to read palette from ghostty config")
            return nil
        }

        return TerminalTheme(
            palette: palette,
            background: background,
            foreground: foreground,
            cursorColor: cursorColor,
            selectionBackground: selectionBg,
            selectionForeground: selectionFg
        )
    }

    // MARK: - Private

    private static func readColor(from config: ghostty_config_t, key: String) -> NSColor? {
        var color = ghostty_config_color_s(r: 0, g: 0, b: 0)
        let found = key.withCString { ghostty_config_get(config, &color, $0, UInt(key.utf8.count)) }
        guard found else { return nil }
        return NSColor(
            srgbRed: CGFloat(color.r) / 255.0,
            green: CGFloat(color.g) / 255.0,
            blue: CGFloat(color.b) / 255.0,
            alpha: 1.0
        )
    }

    private static func readPalette(from config: ghostty_config_t) -> [NSColor]? {
        var palette = ghostty_config_palette_s()
        let key = "palette"
        let found = key.withCString { ghostty_config_get(config, &palette, $0, UInt(key.utf8.count)) }
        guard found else { return nil }

        // palette.colors is a C array of 256 elements, imported as a large tuple.
        // Use withUnsafePointer to index into it.
        return withUnsafePointer(to: &palette.colors) { tuplePtr in
            let base = UnsafeRawPointer(tuplePtr).assumingMemoryBound(to: ghostty_config_color_s.self)
            return (0..<16).map { i in
                let c = base[i]
                return NSColor(
                    srgbRed: CGFloat(c.r) / 255.0,
                    green: CGFloat(c.g) / 255.0,
                    blue: CGFloat(c.b) / 255.0,
                    alpha: 1.0
                )
            }
        }
    }
}
