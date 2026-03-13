import Testing
@testable import HoottyCore

@Suite struct ClaudeTitleParserTests {
    // MARK: - parse

    @Test func brailleSpinnerCharsReturnThinking() {
        // Various Braille chars from U+2800 block used by Claude spinners
        let spinners: [String] = ["\u{280B}", "\u{2819}", "\u{2839}", "\u{2838}", "\u{283C}", "\u{2834}"]
        for char in spinners {
            let title = "\(char) Thinking…"
            #expect(ClaudeTitleParser.parse(title) == .thinking, "Expected .thinking for \(char)")
        }
    }

    @Test func brailleBoundaryCharsReturnThinking() {
        // First and last chars in Braille Patterns block
        #expect(ClaudeTitleParser.parse("\u{2800} title") == .thinking)
        #expect(ClaudeTitleParser.parse("\u{28FF} title") == .thinking)
    }

    @Test func eightSpokedAsteriskReturnsIdle() {
        #expect(ClaudeTitleParser.parse("\u{2733} Claude") == .idle)
    }

    @Test func asciiAsteriskReturnsIdle() {
        #expect(ClaudeTitleParser.parse("* Claude") == .idle)
    }

    @Test func regularTitleReturnsNil() {
        #expect(ClaudeTitleParser.parse("zsh") == nil)
        #expect(ClaudeTitleParser.parse("vim main.swift") == nil)
        #expect(ClaudeTitleParser.parse("~/project") == nil)
    }

    @Test func emptyTitleReturnsNil() {
        #expect(ClaudeTitleParser.parse("") == nil)
    }

    // MARK: - stripPrefix

    @Test func stripPrefixRemovesBrailleAndSpace() {
        let title = "\u{280B} Thinking . project-name"
        #expect(ClaudeTitleParser.stripPrefix(title) == "Thinking . project-name")
    }

    @Test func stripPrefixRemovesAsteriskAndSpace() {
        #expect(ClaudeTitleParser.stripPrefix("* Claude Code") == "Claude Code")
        #expect(ClaudeTitleParser.stripPrefix("\u{2733} Claude Code") == "Claude Code")
    }

    @Test func stripPrefixReturnsNilForRegularTitle() {
        #expect(ClaudeTitleParser.stripPrefix("zsh") == nil)
        #expect(ClaudeTitleParser.stripPrefix("vim") == nil)
    }

    @Test func stripPrefixReturnsNilForEmptyTitle() {
        #expect(ClaudeTitleParser.stripPrefix("") == nil)
    }

    @Test func stripPrefixHandlesNoSpaceAfterIndicator() {
        // Edge case: indicator char with no space
        #expect(ClaudeTitleParser.stripPrefix("*") == "")
        #expect(ClaudeTitleParser.stripPrefix("\u{280B}") == "")
    }
}
