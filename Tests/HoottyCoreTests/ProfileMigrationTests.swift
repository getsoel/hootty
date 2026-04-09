import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct ProfileMigrationTests {
    private func makeTempRoot() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-migration-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func happyPathMigration() throws {
        let root = try makeTempRoot()

        // Create legacy files
        try "theme = Catppuccin Latte\n".write(to: root.appendingPathComponent("config"), atomically: true, encoding: .utf8)
        let snapshot = WorkspaceSnapshot(workspaces: [Workspace(name: "Test")], selectedWorkspaceID: nil)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: root.appendingPathComponent("workspaces.json"), options: .atomic)

        let store = ProfileStore(rootDirectory: root)
        store.migrateIfNeeded()

        // profiles.json should exist
        let metadata = try #require(store.loadMetadata())
        #expect(metadata.profiles.count == 1)
        #expect(metadata.profiles[0].name == "Default")

        // Legacy files should be gone
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("config").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("workspaces.json").path))

        // Files should be in the profile directory
        let profileDir = store.profileDirectory(for: metadata.activeProfileID)
        #expect(FileManager.default.fileExists(atPath: profileDir.appendingPathComponent("config").path))
        #expect(FileManager.default.fileExists(atPath: profileDir.appendingPathComponent("workspaces.json").path))

        // Config content preserved
        let config = try String(contentsOf: profileDir.appendingPathComponent("config"), encoding: .utf8)
        #expect(config.contains("Catppuccin Latte"))
    }

    @Test func noLegacyFilesCreatesFreshMetadata() throws {
        let root = try makeTempRoot()
        let store = ProfileStore(rootDirectory: root)
        store.migrateIfNeeded()

        let metadata = try #require(store.loadMetadata())
        #expect(metadata.profiles.count == 1)
        #expect(metadata.profiles[0].name == "Default")

        // No profile directory yet (lazy creation)
        let profileDir = store.profileDirectory(for: metadata.activeProfileID)
        #expect(!FileManager.default.fileExists(atPath: profileDir.path))
    }

    @Test func alreadyMigratedIsNoOp() throws {
        let root = try makeTempRoot()
        let store = ProfileStore(rootDirectory: root)

        // Pre-populate profiles.json
        let p = Profile(name: "Existing")
        let metadata = ProfilesMetadata(activeProfileID: p.id, profiles: [p])
        store.saveMetadata(metadata)

        // Running migration again should not change anything
        store.migrateIfNeeded()

        let loaded = try #require(store.loadMetadata())
        #expect(loaded.profiles.count == 1)
        #expect(loaded.profiles[0].name == "Existing")
        #expect(loaded.activeProfileID == p.id)
    }

    @Test func partialMigrationRecoveryRefusesToOverwrite() throws {
        let root = try makeTempRoot()

        // Create a profiles/ directory but no profiles.json (simulates crash mid-migration)
        let profilesDir = root.appendingPathComponent("profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)

        let store = ProfileStore(rootDirectory: root)
        store.migrateIfNeeded()

        // Should NOT create profiles.json
        #expect(store.loadMetadata() == nil)
    }

    @Test func migrationWithOnlyConfigFile() throws {
        let root = try makeTempRoot()

        // Only config, no workspaces.json
        try "theme = Catppuccin Mocha\n".write(to: root.appendingPathComponent("config"), atomically: true, encoding: .utf8)

        let store = ProfileStore(rootDirectory: root)
        store.migrateIfNeeded()

        let metadata = try #require(store.loadMetadata())
        let profileDir = store.profileDirectory(for: metadata.activeProfileID)

        #expect(FileManager.default.fileExists(atPath: profileDir.appendingPathComponent("config").path))
        #expect(!FileManager.default.fileExists(atPath: profileDir.appendingPathComponent("workspaces.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("config").path))
    }
}
