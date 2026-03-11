import Foundation

/// Characters that need backslash-escaping when inserting paths into a shell.
/// Matches Ghostty's `Shell.escape` logic.
private let shellSensitiveCharacters = CharacterSet(charactersIn: #" \()[]{}<>"'`!#$&;|*?\t"#)

/// Shell-escapes a string by backslash-prefixing sensitive characters.
func shellEscape(_ input: String) -> String {
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
