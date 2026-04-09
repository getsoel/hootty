import Foundation

/// Detects Google Gemini CLI session indicators from terminal titles.
///
/// Gemini writes titles padded to 80 characters with a distinct leading glyph
/// per activity state:
/// - `◇` (U+25C7) → `.idle` ("Ready")
/// - `✦` (U+2726) → `.thinking` ("Working")
/// - `⏲` (U+23F2) → `.thinking` ("Silent working")
/// - `✋` (U+270B) → `.needsAttention` ("Action Required")
public enum GeminiTitleParser: AgentTitleDetector {
    /// Returns the presence for a leading Gemini indicator, or nil if none.
    private static func presence(for scalar: UnicodeScalar) -> AgentPresence? {
        switch scalar {
        case "\u{25C7}": .idle // ◇
        case "\u{2726}": .thinking // ✦
        case "\u{23F2}": .thinking // ⏲
        case "\u{270B}": .needsAttention // ✋
        default: nil
        }
    }

    public static func detect(_ title: String) -> AgentPresence? {
        guard let first = title.unicodeScalars.first else { return nil }
        return presence(for: first)
    }

    /// Strip the Gemini indicator prefix and surrounding whitespace from a title.
    /// Gemini pads titles to 80 characters with trailing spaces — those are trimmed too.
    public static func stripPrefix(_ title: String) -> String? {
        guard let first = title.unicodeScalars.first else { return nil }
        guard presence(for: first) != nil else { return nil }
        let afterChar = String(title.unicodeScalars.dropFirst())
        let leadingTrimmed = afterChar.drop(while: { $0 == " " })
        // Gemini pads titles to 80 chars with trailing spaces — trim them.
        return String(leadingTrimmed).trimmingCharacters(in: .init(charactersIn: " "))
    }
}
