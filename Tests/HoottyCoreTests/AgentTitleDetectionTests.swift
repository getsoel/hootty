import Testing
@testable import HoottyCore

struct AgentTitleDetectionTests {
    // MARK: - detect fan-out

    @Test func geminiGlyphsDetectedViaGeminiParser() {
        #expect(AgentTitleDetection.detect("\u{25C7}  Ready") == .idle)
        #expect(AgentTitleDetection.detect("\u{2726}  Working") == .thinking)
        #expect(AgentTitleDetection.detect("\u{23F2}  Working…") == .thinking)
        #expect(AgentTitleDetection.detect("\u{270B}  Action Required") == .needsAttention)
    }

    @Test func claudeIdleGlyphsDetectedViaClaudeParser() {
        #expect(AgentTitleDetection.detect("\u{2733} Claude") == .idle)
        #expect(AgentTitleDetection.detect("* Claude") == .idle)
    }

    @Test func brailleGlyphsDetectedAsThinking() {
        // Both Claude and Codex use Braille — first-match-wins (Claude).
        // Result is .thinking regardless of which detector fires.
        #expect(AgentTitleDetection.detect("\u{280B} Thinking") == .thinking)
        #expect(AgentTitleDetection.detect("\u{2819} hootty") == .thinking)
    }

    @Test func nonAgentTitlesReturnNil() {
        #expect(AgentTitleDetection.detect("zsh") == nil)
        #expect(AgentTitleDetection.detect("vim main.swift") == nil)
        #expect(AgentTitleDetection.detect("") == nil)
    }

    // MARK: - stripPrefix fan-out

    @Test func stripPrefixStripsGeminiGlyphsAndPadding() {
        let padded = "\u{25C7}  Ready (my-folder)" + String(repeating: " ", count: 60)
        #expect(AgentTitleDetection.stripPrefix(padded) == "Ready (my-folder)")
    }

    @Test func stripPrefixStripsClaudeBrailleAndSpace() {
        #expect(AgentTitleDetection.stripPrefix("\u{280B} Thinking…") == "Thinking…")
    }

    @Test func stripPrefixStripsClaudeIdleGlyphs() {
        #expect(AgentTitleDetection.stripPrefix("\u{2733} Claude Code") == "Claude Code")
        #expect(AgentTitleDetection.stripPrefix("* Claude Code") == "Claude Code")
    }

    @Test func stripPrefixReturnsNilForNonAgentTitles() {
        #expect(AgentTitleDetection.stripPrefix("zsh") == nil)
        #expect(AgentTitleDetection.stripPrefix("") == nil)
    }

    // MARK: - detector ordering

    @Test func geminiRegisteredBeforeClaudeAndCodex() {
        // Sanity check that Gemini runs first in the registry. If the order
        // is changed, this test fails loudly.
        let ids = AgentTitleDetection.detectors.map { ObjectIdentifier($0) }
        let geminiIndex = ids.firstIndex(of: ObjectIdentifier(GeminiTitleParser.self))
        let claudeIndex = ids.firstIndex(of: ObjectIdentifier(ClaudeTitleParser.self))
        let codexIndex = ids.firstIndex(of: ObjectIdentifier(CodexTitleParser.self))
        #expect(geminiIndex != nil)
        #expect(claudeIndex != nil)
        #expect(codexIndex != nil)
        if let g = geminiIndex, let c = claudeIndex, let cx = codexIndex {
            #expect(g < c)
            #expect(c < cx)
        }
    }
}
