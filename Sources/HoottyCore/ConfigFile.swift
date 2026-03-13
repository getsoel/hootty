import Foundation
import os

@Observable
public final class ConfigFile {
    private static let logger = Logger(subsystem: "com.soel.hootty", category: "config")

    public let fileURL: URL
    private var values: [String: String] = [:]
    private var removedKeys: Set<String> = []
    private var changedKeys: Set<String> = []

    public static var defaultFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #if DEBUG
        let dir = appSupport.appendingPathComponent("Hootty-Dev", isDirectory: true)
        #else
        let dir = appSupport.appendingPathComponent("Hootty", isDirectory: true)
        #endif
        return dir.appendingPathComponent("config")
    }

    /// Application support directory (shared between ConfigFile and GhosttyApp).
    public static var appSupportDirectory: URL {
        defaultFileURL.deletingLastPathComponent()
    }

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    // MARK: - Get / Set

    public func get(_ key: String) -> String? {
        values[key]
    }

    public func set(_ key: String, value: String?) {
        if let value {
            values[key] = value
            removedKeys.remove(key)
            changedKeys.insert(key)
        } else {
            values.removeValue(forKey: key)
            removedKeys.insert(key)
            changedKeys.remove(key)
        }
    }

    // MARK: - Load / Save

    public func load() {
        removedKeys.removeAll()
        changedKeys.removeAll()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Self.logger.info("No config file at \(self.fileURL.path)")
            values = [:]
            return
        }
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            values = Self.parse(content)
            Self.logger.info("Loaded config from \(self.fileURL.path)")
        } catch {
            Self.logger.error("Failed to read config: \(error.localizedDescription)")
            values = [:]
        }
    }

    public func save() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let content: String
        if let existing = try? String(contentsOf: fileURL, encoding: .utf8) {
            content = buildUpdatedContent(from: existing)
        } else {
            content = buildFreshContent()
        }

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            Self.logger.debug("Saved config to \(self.fileURL.path)")
        } catch {
            Self.logger.error("Failed to save config: \(error.localizedDescription)")
        }
        removedKeys.removeAll()
        changedKeys.removeAll()
    }

    /// Creates the default config file if it doesn't exist. Runs migration from old format first.
    public func ensureExists() {
        migrate()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let dir = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? Self.defaultConfigContent().write(to: fileURL, atomically: true, encoding: .utf8)
            load()
        } else {
            load()
        }
    }

    // MARK: - Ghostty Integration

    /// Returns config content with only non-hootty keys (for feeding to ghostty).
    /// Reads the raw file from disk to preserve repeatable keys (e.g. multiple font-family lines).
    /// If `themeOverride` is provided, replaces the theme value without modifying the file on disk.
    public func ghosttyConfigContent(themeOverride: String? = nil) -> String {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            let themeName = themeOverride ?? "Catppuccin Mocha"
            return "theme = \(themeName)\n"
        }
        let lines = content.components(separatedBy: .newlines)
        var filtered = lines.filter { line in
            guard let (key, _) = Self.parseConfigLine(line) else { return true }
            if themeOverride != nil && key == "theme" { return false }
            return !key.hasPrefix("hootty-")
        }
        if let override = themeOverride {
            filtered.insert("theme = \(override)", at: 0)
        }
        let result = filtered.joined(separator: "\n")
        if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let themeName = themeOverride ?? "Catppuccin Mocha"
            return "theme = \(themeName)\n"
        }
        return result.hasSuffix("\n") ? result : result + "\n"
    }

    // MARK: - Parsing

    public static func parse(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            guard let (key, value) = parseConfigLine(line),
                  !key.isEmpty, !value.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    // MARK: - Private

    /// Parses a config line into (key, value), returning nil for comments, blanks, or lines without `=`.
    private static func parseConfigLine(_ line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
              let eqIndex = trimmed.firstIndex(of: "=") else { return nil }
        let key = trimmed[trimmed.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private func buildUpdatedContent(from existing: String) -> String {
        let existingLines = existing.components(separatedBy: .newlines)
        var writtenKeys: Set<String> = []
        var outputLines: [String] = []

        for line in existingLines {
            guard let (key, _) = Self.parseConfigLine(line) else {
                outputLines.append(line)
                continue
            }

            if removedKeys.contains(key) {
                continue
            } else if changedKeys.contains(key) {
                if !writtenKeys.contains(key), let value = values[key] {
                    outputLines.append("\(key) = \(value)")
                    writtenKeys.insert(key)
                }
                // Skip additional occurrences of changed keys
            } else {
                // Pass through verbatim (preserves repeatable keys)
                outputLines.append(line)
            }
        }

        // Append new keys that weren't already in the file
        let newKeys = changedKeys.filter { !writtenKeys.contains($0) && !removedKeys.contains($0) }.sorted()
        for key in newKeys {
            if let value = values[key] {
                outputLines.append("\(key) = \(value)")
            }
        }

        var result = outputLines.joined(separator: "\n")
        if !result.hasSuffix("\n") {
            result.append("\n")
        }
        return result
    }

    private func buildFreshContent() -> String {
        if values.isEmpty {
            return Self.defaultConfigContent()
        }

        var ghosttyLines: [String] = []
        var hoottyLines: [String] = []

        for (key, value) in values.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("hootty-") {
                hoottyLines.append("\(key) = \(value)")
            } else {
                ghosttyLines.append("\(key) = \(value)")
            }
        }

        var lines: [String] = []
        lines.append("# Ghostty settings")
        lines += ghosttyLines
        if !hoottyLines.isEmpty {
            lines.append("")
            lines.append("# Hootty settings")
            lines += hoottyLines
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    static func defaultConfigContent() -> String {
        """
        # Ghostty settings
        theme = Catppuccin Mocha
        font-family = Menlo
        font-family = Apple Symbols

        # Hootty settings
        # hootty-bell-sound = Ping
        # hootty-attention-idle-sound =
        # hootty-attention-input-sound =

        """
    }

    // MARK: - Migration

    private func migrate() {
        let dir = fileURL.deletingLastPathComponent()
        let ghosttyConfigURL = dir.appendingPathComponent("ghostty.config")

        guard FileManager.default.fileExists(atPath: ghosttyConfigURL.path) else { return }

        Self.logger.info("Migrating from old config format...")

        var migratedValues: [String: String] = [:]

        // Read theme from ghostty.config
        if let content = try? String(contentsOf: ghosttyConfigURL, encoding: .utf8) {
            if let theme = Self.parse(content)["theme"] {
                migratedValues["theme"] = theme
            }
        }

        // Fallback: UserDefaults
        if migratedValues["theme"] == nil {
            #if DEBUG
            let defaults = UserDefaults(suiteName: "com.soel.hootty-dev")!
            #else
            let defaults = UserDefaults.standard
            #endif
            if let saved = defaults.string(forKey: "selectedTheme") {
                let migrated = ThemeManager.migrateThemeName("catppuccin-\(saved)")
                migratedValues["theme"] = migrated
            }
        }

        migratedValues["theme"] = migratedValues["theme"] ?? "Catppuccin Mocha"

        // Read old sound config (same path, old format with non-prefixed keys)
        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
            let parsed = Self.parse(content)
            if let v = parsed["bell-sound"] { migratedValues["hootty-bell-sound"] = v }
            if let v = parsed["attention-idle-sound"] { migratedValues["hootty-attention-idle-sound"] = v }
            if let v = parsed["attention-input-sound"] { migratedValues["hootty-attention-input-sound"] = v }
            // Already-prefixed keys take priority
            if let v = parsed["hootty-bell-sound"] { migratedValues["hootty-bell-sound"] = v }
            if let v = parsed["hootty-attention-idle-sound"] { migratedValues["hootty-attention-idle-sound"] = v }
            if let v = parsed["hootty-attention-input-sound"] { migratedValues["hootty-attention-input-sound"] = v }
        }

        // Write unified config
        values = migratedValues
        removedKeys.removeAll()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = buildFreshContent()
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Delete old ghostty.config
        try? FileManager.default.removeItem(at: ghosttyConfigURL)
        Self.logger.info("Migration complete, removed \(ghosttyConfigURL.path)")

        // Remove UserDefaults key
        #if DEBUG
        UserDefaults(suiteName: "com.soel.hootty-dev")?.removeObject(forKey: "selectedTheme")
        #else
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
        #endif
    }
}
