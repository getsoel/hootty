import os

enum Log {
    static let ghostty = Logger(subsystem: "com.soel.hootty", category: "ghostty")
    static let surface = Logger(subsystem: "com.soel.hootty", category: "surface")
    static let lifecycle = Logger(subsystem: "com.soel.hootty", category: "lifecycle")
    static let ui = Logger(subsystem: "com.soel.hootty", category: "ui")
}
