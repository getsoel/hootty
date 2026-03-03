import Foundation

struct ANSIStyle: Equatable, Sendable {
    enum Color: Equatable, Sendable {
        case `default`
        case standard(UInt8)    // 0-7 standard, 8-15 bright
        case palette(UInt8)     // 0-255
        case rgb(UInt8, UInt8, UInt8)
    }

    var foreground: Color = .default
    var background: Color = .default
    var bold: Bool = false
    var dim: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var strikethrough: Bool = false

    static let reset = ANSIStyle()
}
