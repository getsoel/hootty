import os

enum Log {
    static let ghostty = Logger(subsystem: "com.soel.klaude", category: "ghostty")
    static let surface = Logger(subsystem: "com.soel.klaude", category: "surface")
    static let lifecycle = Logger(subsystem: "com.soel.klaude", category: "lifecycle")
    static let ui = Logger(subsystem: "com.soel.klaude", category: "ui")
}
