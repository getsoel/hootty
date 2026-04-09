import Testing
@testable import HoottyCore

struct GeminiTitleParserTests {
    // MARK: - detect

    @Test func diamondIndicatesIdle() {
        #expect(GeminiTitleParser.detect("\u{25C7}  Ready (my-folder)") == .idle)
    }

    @Test func fourPointedStarIndicatesThinking() {
        #expect(GeminiTitleParser.detect("\u{2726}  Working…") == .thinking)
    }

    @Test func timerIndicatesThinking() {
        #expect(GeminiTitleParser.detect("\u{23F2}  Working… (my-folder)") == .thinking)
    }

    @Test func raisedHandIndicatesNeedsAttention() {
        #expect(GeminiTitleParser.detect("\u{270B}  Action Required (my-folder)") == .needsAttention)
    }

    @Test func nonGeminiTitlesReturnNil() {
        #expect(GeminiTitleParser.detect("zsh") == nil)
        #expect(GeminiTitleParser.detect("vim main.swift") == nil)
        #expect(GeminiTitleParser.detect("\u{2733} Claude") == nil) // Claude idle glyph
        #expect(GeminiTitleParser.detect("\u{280B} Thinking") == nil) // Braille — Claude/Codex
    }

    @Test func emptyTitleReturnsNil() {
        #expect(GeminiTitleParser.detect("") == nil)
    }

    // MARK: - stripPrefix

    @Test func stripPrefixRemovesDiamondAndTwoSpaces() {
        #expect(GeminiTitleParser.stripPrefix("\u{25C7}  Ready (my-folder)") == "Ready (my-folder)")
    }

    @Test func stripPrefixTrimsTrailingPadding() {
        // Gemini pads titles to 80 chars with trailing spaces
        let padded = "\u{2726}  Working…" + String(repeating: " ", count: 70)
        #expect(GeminiTitleParser.stripPrefix(padded) == "Working…")
    }

    @Test func stripPrefixHandlesRaisedHand() {
        #expect(GeminiTitleParser.stripPrefix("\u{270B}  Action Required") == "Action Required")
    }

    @Test func stripPrefixReturnsNilForNonGeminiTitle() {
        #expect(GeminiTitleParser.stripPrefix("zsh") == nil)
        #expect(GeminiTitleParser.stripPrefix("\u{2733} Claude") == nil)
    }

    @Test func stripPrefixReturnsNilForEmptyTitle() {
        #expect(GeminiTitleParser.stripPrefix("") == nil)
    }

    @Test func stripPrefixHandlesGlyphOnly() {
        #expect(GeminiTitleParser.stripPrefix("\u{25C7}") == "")
    }
}
