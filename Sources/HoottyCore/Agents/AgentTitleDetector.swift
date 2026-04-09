import Foundation

/// A pluggable detector that recognizes a particular agent CLI's terminal-title
/// patterns and extracts its activity state.
///
/// Concrete detectors (e.g. `ClaudeTitleParser`, `GeminiTitleParser`,
/// `CodexTitleParser`) are registered in `AgentTitleDetection.detectors` and
/// consulted in order on each title change.
public protocol AgentTitleDetector {
    /// Inspect a terminal title and return the detected presence, or `nil`
    /// if the title does not match this agent's pattern.
    static func detect(_ title: String) -> AgentPresence?

    /// Return the title with this agent's indicator prefix and any adjacent
    /// whitespace removed, or `nil` if the title does not match.
    static func stripPrefix(_ title: String) -> String?
}

/// Registry and dispatch entry point for agent title detection.
///
/// Runs registered detectors in order and returns the first non-nil result.
/// Adding a new agent is one new file conforming to `AgentTitleDetector` plus
/// one entry in `detectors`.
public enum AgentTitleDetection {
    /// Detectors are consulted in this order. Gemini is first because its
    /// glyphs (`◇✦⏲✋`) are distinct and fastest to reject. Claude handles
    /// both Braille and `✳`/`*`. Codex is last because its Braille rule
    /// duplicates Claude's — kept for discoverability.
    public static let detectors: [any AgentTitleDetector.Type] = [
        GeminiTitleParser.self,
        ClaudeTitleParser.self,
        CodexTitleParser.self
    ]

    /// Run all detectors against `title` and return the first non-nil result.
    public static func detect(_ title: String) -> AgentPresence? {
        for detector in detectors {
            if let presence = detector.detect(title) {
                return presence
            }
        }
        return nil
    }

    /// Run all detectors' `stripPrefix` against `title` and return the first
    /// non-nil cleaned string.
    public static func stripPrefix(_ title: String) -> String? {
        for detector in detectors {
            if let cleaned = detector.stripPrefix(title) {
                return cleaned
            }
        }
        return nil
    }
}
