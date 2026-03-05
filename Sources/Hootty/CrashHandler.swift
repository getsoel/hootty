import Foundation
import os

enum CrashHandler {
    private static let logger = Logger(subsystem: "com.soel.hootty", category: "crash")
    private static let logDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Hootty")
    private static let logFile = logDirectory.appendingPathComponent("crash.log")

    static func install() {
        // Create log directory if needed
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // Catch uncaught ObjC exceptions
        NSSetUncaughtExceptionHandler { exception in
            let info = """
                === Hootty Crash Report ===
                Date: \(ISO8601DateFormatter().string(from: Date()))
                Exception: \(exception.name.rawValue)
                Reason: \(exception.reason ?? "unknown")
                Call Stack:
                \(exception.callStackSymbols.joined(separator: "\n"))
                ===========================
                """
            CrashHandler.logger.fault("Uncaught exception: \(exception.name.rawValue) — \(exception.reason ?? "unknown")")
            CrashHandler.writeCrashLog(info)
        }

        // Install signal handlers
        let signals: [(Int32, String)] = [
            (SIGABRT, "SIGABRT"),
            (SIGSEGV, "SIGSEGV"),
            (SIGBUS, "SIGBUS"),
            (SIGFPE, "SIGFPE"),
            (SIGILL, "SIGILL"),
        ]

        for (sig, _) in signals {
            signal(sig) { receivedSignal in
                let name: String
                switch receivedSignal {
                case SIGABRT: name = "SIGABRT"
                case SIGSEGV: name = "SIGSEGV"
                case SIGBUS: name = "SIGBUS"
                case SIGFPE: name = "SIGFPE"
                case SIGILL: name = "SIGILL"
                default: name = "SIGNAL(\(receivedSignal))"
                }

                let info = """
                    === Hootty Crash Report ===
                    Date: \(ISO8601DateFormatter().string(from: Date()))
                    Signal: \(name) (\(receivedSignal))
                    Thread: \(Thread.current)
                    Call Stack:
                    \(Thread.callStackSymbols.joined(separator: "\n"))
                    ===========================
                    """
                CrashHandler.writeCrashLog(info)

                // Re-raise with default handler so the process terminates normally
                signal(receivedSignal, SIG_DFL)
                raise(receivedSignal)
            }
        }

        logger.info("Crash handlers installed")
    }

    private static func writeCrashLog(_ content: String) {
        // Use low-level write to be signal-safe (avoid allocations where possible)
        let data = Data(content.utf8)
        try? data.write(to: logFile, options: .atomic)
    }
}
