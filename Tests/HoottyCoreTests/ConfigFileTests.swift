import Testing
import Foundation
@testable import HoottyCore

@Suite struct ConfigFileTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
    }

    private func tempFileURL() -> URL {
        tempDir().appendingPathComponent("config")
    }

    // MARK: - Parsing

    @Test func parseKeyValueLines() {
        let content = """
        theme = catppuccin-mocha
        hootty-bell-sound = Ping
        hootty-attention-idle-sound = Glass
        """
        let parsed = ConfigFile.parse(content)
        #expect(parsed["theme"] == "catppuccin-mocha")
        #expect(parsed["hootty-bell-sound"] == "Ping")
        #expect(parsed["hootty-attention-idle-sound"] == "Glass")
    }

    @Test func parseIgnoresCommentsAndBlankLines() {
        let content = """
        # This is a comment

        theme = catppuccin-mocha
        # hootty-bell-sound = Ping
        """
        let parsed = ConfigFile.parse(content)
        #expect(parsed["theme"] == "catppuccin-mocha")
        #expect(parsed["hootty-bell-sound"] == nil)
    }

    @Test func parseIgnoresEmptyValues() {
        let content = """
        theme =
        hootty-bell-sound = Ping
        """
        let parsed = ConfigFile.parse(content)
        #expect(parsed["theme"] == nil)
        #expect(parsed["hootty-bell-sound"] == "Ping")
    }

    // MARK: - Get / Set

    @Test func getReturnsNilForMissingKey() {
        let config = ConfigFile(fileURL: tempFileURL())
        #expect(config.get("nonexistent") == nil)
    }

    @Test func setAndGetRoundTrip() {
        let config = ConfigFile(fileURL: tempFileURL())
        config.set("theme", value: "catppuccin-frappe")
        #expect(config.get("theme") == "catppuccin-frappe")
    }

    @Test func setNilRemovesKey() {
        let config = ConfigFile(fileURL: tempFileURL())
        config.set("theme", value: "catppuccin-mocha")
        config.set("theme", value: nil)
        #expect(config.get("theme") == nil)
    }

    // MARK: - Load / Save

    @Test func roundTripWriteAndRead() {
        let url = tempFileURL()
        let config1 = ConfigFile(fileURL: url)
        config1.set("theme", value: "catppuccin-frappe")
        config1.set("hootty-bell-sound", value: "Ping")
        config1.save()

        let config2 = ConfigFile(fileURL: url)
        #expect(config2.get("theme") == "catppuccin-frappe")
        #expect(config2.get("hootty-bell-sound") == "Ping")
    }

    @Test func savePreservesUnknownKeys() {
        let url = tempFileURL()
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write a file with an unknown key
        let content = """
        theme = catppuccin-mocha
        font-size = 14
        hootty-bell-sound = Ping
        """
        try? content.write(to: url, atomically: true, encoding: .utf8)

        let config = ConfigFile(fileURL: url)
        config.set("theme", value: "catppuccin-frappe")
        config.save()

        // Reload and verify unknown key preserved
        let config2 = ConfigFile(fileURL: url)
        #expect(config2.get("theme") == "catppuccin-frappe")
        #expect(config2.get("font-size") == "14")
        #expect(config2.get("hootty-bell-sound") == "Ping")
    }

    @Test func saveRemovesExplicitlyDeletedKeys() {
        let url = tempFileURL()
        let config1 = ConfigFile(fileURL: url)
        config1.set("theme", value: "catppuccin-mocha")
        config1.set("hootty-bell-sound", value: "Ping")
        config1.save()

        let config2 = ConfigFile(fileURL: url)
        config2.set("hootty-bell-sound", value: nil)
        config2.save()

        let config3 = ConfigFile(fileURL: url)
        #expect(config3.get("theme") == "catppuccin-mocha")
        #expect(config3.get("hootty-bell-sound") == nil)
    }

    @Test func savePreservesComments() {
        let url = tempFileURL()
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let content = """
        # Ghostty settings
        theme = catppuccin-mocha

        # Hootty settings
        hootty-bell-sound = Ping
        """
        try? content.write(to: url, atomically: true, encoding: .utf8)

        let config = ConfigFile(fileURL: url)
        config.set("theme", value: "catppuccin-frappe")
        config.save()

        let raw = try! String(contentsOf: url, encoding: .utf8)
        #expect(raw.contains("# Ghostty settings"))
        #expect(raw.contains("# Hootty settings"))
        #expect(raw.contains("theme = catppuccin-frappe"))
    }

    // MARK: - Ensure Exists

    @Test func ensureExistsCreatesDefaultFile() {
        let url = tempFileURL()
        let config = ConfigFile(fileURL: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        config.ensureExists()
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(config.get("theme") == "Catppuccin Mocha")
    }

    @Test func ensureExistsDoesNotOverwriteExisting() {
        let url = tempFileURL()
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let content = "theme = catppuccin-frappe\nhootty-bell-sound = Ping\n"
        try? content.write(to: url, atomically: true, encoding: .utf8)

        let config = ConfigFile(fileURL: url)
        config.ensureExists()
        #expect(config.get("theme") == "catppuccin-frappe")
        #expect(config.get("hootty-bell-sound") == "Ping")
    }

    // MARK: - Ghostty Integration

    @Test func ghosttyConfigContentFiltersHoottyKeys() {
        let config = ConfigFile(fileURL: tempFileURL())
        config.set("theme", value: "catppuccin-mocha")
        config.set("font-size", value: "14")
        config.set("hootty-bell-sound", value: "Ping")
        config.set("hootty-attention-idle-sound", value: "Glass")

        let content = config.ghosttyConfigContent()
        #expect(content.contains("theme = catppuccin-mocha"))
        #expect(content.contains("font-size = 14"))
        #expect(!content.contains("hootty-"))
    }

    @Test func ghosttyConfigContentDefaultsWhenEmpty() {
        let config = ConfigFile(fileURL: tempFileURL())
        let content = config.ghosttyConfigContent()
        #expect(content.contains("Catppuccin Mocha"))
    }

    // MARK: - Migration

    @Test func migrationFromGhosttyConfig() {
        let dir = tempDir()
        let configURL = dir.appendingPathComponent("config")
        let ghosttyConfigURL = dir.appendingPathComponent("ghostty.config")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write old ghostty.config
        try? "theme = catppuccin-frappe\n".write(to: ghosttyConfigURL, atomically: true, encoding: .utf8)

        let config = ConfigFile(fileURL: configURL)
        config.ensureExists()

        #expect(config.get("theme") == "catppuccin-frappe")
        #expect(!FileManager.default.fileExists(atPath: ghosttyConfigURL.path))
    }

    @Test func migrationReadsSoundSettingsWithOldKeys() {
        let dir = tempDir()
        let configURL = dir.appendingPathComponent("config")
        let ghosttyConfigURL = dir.appendingPathComponent("ghostty.config")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write old ghostty.config
        try? "theme = catppuccin-mocha\n".write(to: ghosttyConfigURL, atomically: true, encoding: .utf8)
        // Write old sound config with non-prefixed keys
        try? "bell-sound = Ping\nattention-idle-sound = Glass\n".write(to: configURL, atomically: true, encoding: .utf8)

        let config = ConfigFile(fileURL: configURL)
        config.ensureExists()

        #expect(config.get("theme") == "catppuccin-mocha")
        #expect(config.get("hootty-bell-sound") == "Ping")
        #expect(config.get("hootty-attention-idle-sound") == "Glass")
        #expect(!FileManager.default.fileExists(atPath: ghosttyConfigURL.path))
    }

    @Test func migrationDoesNothingWithoutGhosttyConfig() {
        let dir = tempDir()
        let configURL = dir.appendingPathComponent("config")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write a config file without ghostty.config — no migration needed
        try? "theme = catppuccin-frappe\nhootty-bell-sound = Basso\n".write(to: configURL, atomically: true, encoding: .utf8)

        let config = ConfigFile(fileURL: configURL)
        config.ensureExists()

        // Values should be preserved as-is
        #expect(config.get("theme") == "catppuccin-frappe")
        #expect(config.get("hootty-bell-sound") == "Basso")
    }
}
