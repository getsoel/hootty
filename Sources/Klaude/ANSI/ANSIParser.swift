import Foundation

/// State machine ANSI parser. Handles SGR (Select Graphic Rendition) sequences only.
/// Cursor movement, screen clearing, and other sequences are silently dropped.
/// Maintains state across parse() calls for correct handling of split reads.
final class ANSIParser {
    private enum State {
        case ground
        case escape       // saw ESC
        case csiEntry     // saw ESC [
        case oscString    // saw ESC ]
    }

    private var state: State = .ground
    private var currentStyle = ANSIStyle()
    private var textBuffer = ""
    private var paramBuffer = ""

    /// Parse a chunk of text and return styled segments.
    func parse(_ input: String) -> [StyledSegment] {
        var segments: [StyledSegment] = []

        func flushText() {
            if !textBuffer.isEmpty {
                segments.append(StyledSegment(text: textBuffer, style: currentStyle))
                textBuffer = ""
            }
        }

        for char in input {
            switch state {
            case .ground:
                if char == "\u{1B}" {
                    flushText()
                    state = .escape
                } else {
                    textBuffer.append(char)
                }

            case .escape:
                switch char {
                case "[":
                    state = .csiEntry
                    paramBuffer = ""
                case "]":
                    state = .oscString
                    paramBuffer = ""
                case "(", ")":
                    // Character set designation — skip one more char
                    state = .ground
                default:
                    // Unknown escape, discard and return to ground
                    state = .ground
                }

            case .csiEntry:
                if char.isCSIParameter {
                    paramBuffer.append(char)
                } else if char.isCSIIntermediate {
                    // Intermediate bytes — ignore but stay in CSI
                } else {
                    // Final byte — dispatch or discard
                    if char == "m" {
                        applySGR(paramBuffer)
                    }
                    // All other CSI sequences silently dropped
                    state = .ground
                }

            case .oscString:
                // OSC terminated by BEL (\x07) or ST (ESC \)
                if char == "\u{07}" {
                    state = .ground
                } else if char == "\u{1B}" {
                    // Could be start of ST — just go back to escape
                    state = .escape
                } else {
                    // Consume OSC content silently
                }
            }
        }

        flushText()
        return segments
    }

    /// Apply SGR parameters to currentStyle
    private func applySGR(_ params: String) {
        let codes = params.split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) ?? 0 }

        if codes.isEmpty {
            currentStyle = .reset
            return
        }

        var i = 0
        while i < codes.count {
            let code = codes[i]
            switch code {
            case 0:
                currentStyle = .reset
            case 1:
                currentStyle.bold = true
            case 2:
                currentStyle.dim = true
            case 3:
                currentStyle.italic = true
            case 4:
                currentStyle.underline = true
            case 9:
                currentStyle.strikethrough = true
            case 22:
                currentStyle.bold = false
                currentStyle.dim = false
            case 23:
                currentStyle.italic = false
            case 24:
                currentStyle.underline = false
            case 29:
                currentStyle.strikethrough = false

            // Standard foreground: 30-37
            case 30...37:
                currentStyle.foreground = .standard(UInt8(code - 30))
            // Bright foreground: 90-97
            case 90...97:
                currentStyle.foreground = .standard(UInt8(code - 90 + 8))
            case 39:
                currentStyle.foreground = .default

            // Extended foreground: 38;5;n or 38;2;r;g;b
            case 38:
                if let color = parseExtendedColor(codes, at: &i) {
                    currentStyle.foreground = color
                }

            // Standard background: 40-47
            case 40...47:
                currentStyle.background = .standard(UInt8(code - 40))
            // Bright background: 100-107
            case 100...107:
                currentStyle.background = .standard(UInt8(code - 100 + 8))
            case 49:
                currentStyle.background = .default

            // Extended background: 48;5;n or 48;2;r;g;b
            case 48:
                if let color = parseExtendedColor(codes, at: &i) {
                    currentStyle.background = color
                }

            default:
                break
            }
            i += 1
        }
    }

    /// Parse extended color: 5;n (256-color) or 2;r;g;b (truecolor).
    /// Advances `i` past consumed parameters.
    private func parseExtendedColor(_ codes: [Int], at i: inout Int) -> ANSIStyle.Color? {
        i += 1
        guard i < codes.count else { return nil }
        if codes[i] == 5, i + 1 < codes.count {
            i += 1
            return .palette(UInt8(clamping: codes[i]))
        } else if codes[i] == 2, i + 3 < codes.count {
            let r = UInt8(clamping: codes[i + 1])
            let g = UInt8(clamping: codes[i + 2])
            let b = UInt8(clamping: codes[i + 3])
            i += 3
            return .rgb(r, g, b)
        }
        return nil
    }
}

// MARK: - Character helpers

private extension Character {
    /// CSI parameter bytes: digits, semicolons
    var isCSIParameter: Bool {
        let s = self.asciiValue ?? 0
        return (s >= 0x30 && s <= 0x3B)  // 0-9, :, ;
    }

    /// CSI intermediate bytes: 0x20–0x2F
    var isCSIIntermediate: Bool {
        let s = self.asciiValue ?? 0
        return (s >= 0x20 && s <= 0x2F)
    }
}
