import Foundation
import os

/// Persists memory samples to disk so the trajectory survives jetsam kills.
/// Writes a rolling CSV log and emits os.Logger warnings at threshold crossings.
enum MemoryLogger {
    #if DEBUG
        private static let logDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Hootty-Dev")
    #else
        private static let logDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Hootty")
    #endif
    private static let logFile = logDirectory.appendingPathComponent("memory.csv")
    private static let maxLines = 600 // ~5 hours at 30s intervals

    private static var lineCount = 0
    private static var lastDiskWriteMB = 0
    private static var lastThresholdCrossed = 0
    private static let thresholds = [512, 1024, 1536, 2048, 3072, 4096]

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Call once at startup to create the log directory and write the CSV header.
    static func install() {
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let header = "timestamp,memory_mb,panes,surfaces,delta_mb\n"
        try? header.write(to: logFile, atomically: true, encoding: .utf8)
        lineCount = 0
        lastDiskWriteMB = 0
        lastThresholdCrossed = 0
        Log.memory.info("Memory logger installed: \(logFile.path)")
    }

    /// Record a sample. Writes to disk every 30s (when sampleIndex % 30 == 0)
    /// or immediately on large jumps (>50 MB since last write).
    static func record(
        sampleIndex: Int,
        memoryMB: Int,
        paneCount: Int,
        surfaceCount: Int,
        deltaMB: Int?
    ) {
        // Threshold crossing warnings via os.Logger (persists in unified log)
        for threshold in thresholds where memoryMB >= threshold && lastThresholdCrossed < threshold {
            lastThresholdCrossed = threshold
            Log.memory.warning(
                "Memory crossed \(threshold) MB — current: \(memoryMB) MB, panes: \(paneCount), surfaces: \(surfaceCount)"
            )
        }
        // Reset threshold when memory drops
        if memoryMB < lastThresholdCrossed {
            lastThresholdCrossed = thresholds.last(where: { memoryMB >= $0 }) ?? 0
        }

        // Surface leak warning
        if surfaceCount > paneCount {
            Log.memory.warning(
                "Surface leak suspected — surfaces: \(surfaceCount) > panes: \(paneCount), memory: \(memoryMB) MB"
            )
        }

        // Write to disk periodically or on large jumps
        let largeJump = abs(memoryMB - lastDiskWriteMB) > 50
        let periodicWrite = sampleIndex % 30 == 0
        guard periodicWrite || largeJump else { return }

        appendSample(
            memoryMB: memoryMB,
            paneCount: paneCount,
            surfaceCount: surfaceCount,
            deltaMB: deltaMB
        )
    }

    private static func appendSample(
        memoryMB: Int,
        paneCount: Int,
        surfaceCount: Int,
        deltaMB: Int?
    ) {
        let line = "\(isoFormatter.string(from: Date())),\(memoryMB),\(paneCount),\(surfaceCount),\(deltaMB.map(String.init) ?? "")\n"

        lastDiskWriteMB = memoryMB
        lineCount += 1

        // Append to file
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }

        // Truncate if too large (keep last maxLines)
        if lineCount > maxLines, lineCount % 100 == 0 {
            truncateLog()
        }
    }

    private static func truncateLog() {
        guard let content = try? String(contentsOf: logFile, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n")
        guard lines.count > maxLines + 1 else { return } // +1 for header
        let header = lines.removeFirst()
        let kept = lines.suffix(maxLines)
        let truncated = header + "\n" + kept.joined(separator: "\n")
        try? truncated.write(to: logFile, atomically: true, encoding: .utf8)
        lineCount = kept.count
    }
}
