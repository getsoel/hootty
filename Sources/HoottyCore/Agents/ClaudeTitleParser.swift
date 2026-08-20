import Foundation

/// Detects Claude Code session indicators from terminal titles.
///
/// Claude Code writes `<glyph> <title>` and swaps the glyph by state:
/// - Half-filled circles `◐◑◒◓` (U+25D0–U+25D3) → `.thinking` (spinner frames,
///   introduced in Claude Code 2.x; it previously spun Braille glyphs)
/// - Braille Patterns block (U+2800–U+28FF) → `.thinking` (legacy spinner)
/// - Eight Spoked Asterisk `✳` (U+2733) → `.idle`
/// - ASCII `*` → `.idle`
///
/// Note: OpenAI Codex CLI also emits Braille spinners as its thinking
/// indicator, so this detector will match Codex thinking states transitively.
/// See `CodexTitleParser` for the dedicated (functionally equivalent) Codex
/// detector kept in the registry for discoverability.
public enum ClaudeTitleParser: AgentTitleDetector {
    /// Returns the presence for a leading Claude Code indicator, or nil if none.
    private static func presence(for scalar: UnicodeScalar) -> AgentPresence? {
        switch scalar.value {
        // ◐◑◒◓ — current spinner frames.
        case 0x25D0 ... 0x25D3: .thinking
        // Braille Patterns — spinner used by older Claude Code (and Codex).
        case 0x2800 ... 0x28FF: .thinking
        // ✳ and its ASCII fallback — Claude is parked at the prompt.
        case 0x2733, 0x2A: .idle
        default: nil
        }
    }

    public static func detect(_ title: String) -> AgentPresence? {
        guard let first = title.unicodeScalars.first else { return nil }
        return presence(for: first)
    }

    /// Strip the Claude Code indicator prefix (spinner/idle char + space) from a title.
    /// Returns the cleaned title, or `nil` if the title doesn't have a Claude prefix.
    public static func stripPrefix(_ title: String) -> String? {
        guard let first = title.unicodeScalars.first else { return nil }
        guard presence(for: first) != nil else { return nil }
        // Drop the indicator character, then any leading whitespace
        let afterChar = String(title.unicodeScalars.dropFirst())
        let trimmed = afterChar.drop(while: { $0 == " " })
        return String(trimmed)
    }
}
