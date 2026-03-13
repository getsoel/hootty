import Foundation

public enum ClaudeTitleParser {
    public enum State: Equatable {
        case thinking
        case idle
    }

    /// Whether the scalar is a Claude Code indicator: Braille spinner (U+2800–U+28FF),
    /// Eight Spoked Asterisk (U+2733), or ASCII `*`.
    private static func isClaudeIndicator(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 0x2800 && scalar.value <= 0x28FF)
            || scalar == "\u{2733}"
            || scalar == "*"
    }

    /// Parse a terminal title for Claude Code state indicators.
    /// Returns `.thinking` for Braille spinner chars (U+2800–U+28FF),
    /// `.idle` for `✳` (U+2733) or ASCII `*`, or `nil` if not a Claude title.
    public static func parse(_ title: String) -> State? {
        guard let first = title.unicodeScalars.first else { return nil }
        guard isClaudeIndicator(first) else { return nil }
        // Braille Patterns block: U+2800–U+28FF → thinking (spinner)
        if first.value >= 0x2800 && first.value <= 0x28FF {
            return .thinking
        }
        return .idle
    }

    /// Strip the Claude Code indicator prefix (spinner/idle char + space) from a title.
    /// Returns the cleaned title, or `nil` if the title doesn't have a Claude prefix.
    public static func stripPrefix(_ title: String) -> String? {
        guard let first = title.unicodeScalars.first else { return nil }
        guard isClaudeIndicator(first) else { return nil }
        // Drop the indicator character, then any leading whitespace
        let afterChar = String(title.unicodeScalars.dropFirst())
        let trimmed = afterChar.drop(while: { $0 == " " })
        return String(trimmed)
    }
}
