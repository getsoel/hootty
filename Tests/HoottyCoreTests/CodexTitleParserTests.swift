import Testing
@testable import HoottyCore

struct CodexTitleParserTests {
    // MARK: - detect

    @Test func brailleSpinnerIndicatesThinking() {
        // Codex uses the same Braille spinner frames as Claude
        let frames: [String] = ["\u{280B}", "\u{2819}", "\u{2839}", "\u{2838}", "\u{283C}", "\u{2834}"]
        for frame in frames {
            #expect(CodexTitleParser.detect("\(frame) hootty") == .thinking)
        }
    }

    @Test func brailleBoundaryCharsIndicateThinking() {
        #expect(CodexTitleParser.detect("\u{2800} project") == .thinking)
        #expect(CodexTitleParser.detect("\u{28FF} project") == .thinking)
    }

    @Test func plainProjectNameReturnsNil() {
        // Codex has no idle glyph — idle titles look like ordinary text.
        #expect(CodexTitleParser.detect("hootty") == nil)
        #expect(CodexTitleParser.detect("my-project") == nil)
    }

    @Test func asteriskReturnsNil() {
        // Codex does NOT use Claude's idle glyphs
        #expect(CodexTitleParser.detect("* hootty") == nil)
        #expect(CodexTitleParser.detect("\u{2733} hootty") == nil)
    }

    @Test func geminiGlyphsReturnNil() {
        #expect(CodexTitleParser.detect("\u{25C7}  Ready") == nil)
        #expect(CodexTitleParser.detect("\u{2726}  Working") == nil)
    }

    @Test func emptyTitleReturnsNil() {
        #expect(CodexTitleParser.detect("") == nil)
    }

    // MARK: - stripPrefix

    @Test func stripPrefixRemovesBrailleAndSpace() {
        #expect(CodexTitleParser.stripPrefix("\u{280B} my-project") == "my-project")
    }

    @Test func stripPrefixReturnsNilForNonBrailleTitle() {
        #expect(CodexTitleParser.stripPrefix("hootty") == nil)
        #expect(CodexTitleParser.stripPrefix("* Claude") == nil)
    }

    @Test func stripPrefixReturnsNilForEmptyTitle() {
        #expect(CodexTitleParser.stripPrefix("") == nil)
    }
}
