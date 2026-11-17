import Foundation

/// Characters that need backslash-escaping when inserting paths into a shell.
/// Matches Ghostty's `Shell.escape` logic.
private let shellSensitiveCharacters = CharacterSet(charactersIn: "\\ ()[]{}<>\"'`!#$&;|*?\t")

/// Shell-escapes a string by backslash-prefixing sensitive characters.
///
/// - Important: Escaping can't protect typed input from control characters:
///   Ctrl-U or Return act as keys the moment they arrive. Check the original
///   string with ``containsControlCharacters(_:)`` and reject it first.
public func shellEscape(_ input: String) -> String {
    var result = ""
    result.reserveCapacity(input.count)
    for scalar in input.unicodeScalars {
        if shellSensitiveCharacters.contains(scalar) {
            result.append("\\")
        }
        result.append(Character(scalar))
    }
    return result
}

/// Whether `input` contains a Unicode control character (U+0000–U+001F,
/// U+007F, U+0080–U+009F). A file named `Foo<Ctrl-U>ls<Return>` would erase
/// the escaped path and run `ls` when typed into a terminal, and the
/// characters are invisible, so such strings are rejected rather than escaped.
/// Matches Ghostty's `Shell.containsControlCharacters` (GHSA-mxqx-236q-wrv7).
public func containsControlCharacters(_ input: String) -> Bool {
    input.unicodeScalars.contains { $0.properties.generalCategory == .control }
}
