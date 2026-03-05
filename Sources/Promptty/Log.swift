import os

enum Log {
    static let ghostty = Logger(subsystem: "com.soel.promptty", category: "ghostty")
    static let surface = Logger(subsystem: "com.soel.promptty", category: "surface")
    static let lifecycle = Logger(subsystem: "com.soel.promptty", category: "lifecycle")
    static let ui = Logger(subsystem: "com.soel.promptty", category: "ui")
}
