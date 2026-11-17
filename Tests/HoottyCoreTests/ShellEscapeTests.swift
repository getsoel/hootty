import Testing
@testable import HoottyCore

struct ShellEscapeTests {
    @Test func escapesShellSensitiveCharacters() {
        #expect(shellEscape("/tmp/my file (1).txt") == #"/tmp/my\ file\ \(1\).txt"#)
        #expect(shellEscape("$HOME;rm") == #"\$HOME\;rm"#)
        #expect(shellEscape("a\\b\tc") == "a\\\\b\\\tc")
    }

    /// GHSA-mxqx-236q-wrv7: a dropped file named `Foo<Ctrl-U>ls<Return>`
    /// would erase the typed path and run `ls`; escaping can't stop that.
    @Test(arguments: ["/tmp/Foo\u{15}ls\r", "/tmp/a\nb", "/tmp/a\u{1B}[2J", "/tmp/a\u{7F}", "/tmp/a\u{85}"])
    func detectsControlCharacters(_ path: String) {
        #expect(containsControlCharacters(path))
    }

    @Test(arguments: ["/tmp/plain.txt", "/tmp/my file.txt", "/tmp/café ☕️.txt"])
    func allowsOrdinaryPaths(_ path: String) {
        #expect(!containsControlCharacters(path))
    }
}
