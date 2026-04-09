import Foundation

/// Detects OpenAI Codex CLI session indicators from terminal titles.
///
/// Codex uses the Braille Patterns block (U+2800–U+28FF) as its thinking
/// spinner. It has no dedicated idle or needs-attention glyph — the title
/// simply collapses to the plain project name when idle. The implicit-idle
/// branch in `PaneEventHandler.handleTitleChange` handles the thinking → idle
/// transition when titles stop matching any detector.
///
/// Note: this detector duplicates `ClaudeTitleParser`'s Braille rule and is
/// functionally equivalent to Claude's detector for those characters. It is
/// retained as a dedicated file for discoverability and future divergence.
public enum CodexTitleParser: AgentTitleDetector {
    private static func isCodexIndicator(_ scalar: UnicodeScalar) -> Bool {
        scalar.value >= 0x2800 && scalar.value <= 0x28FF
    }

    public static func detect(_ title: String) -> AgentPresence? {
        guard let first = title.unicodeScalars.first else { return nil }
        return isCodexIndicator(first) ? .thinking : nil
    }

    public static func stripPrefix(_ title: String) -> String? {
        guard let first = title.unicodeScalars.first else { return nil }
        guard isCodexIndicator(first) else { return nil }
        let afterChar = String(title.unicodeScalars.dropFirst())
        let trimmed = afterChar.drop(while: { $0 == " " })
        return String(trimmed)
    }
}
