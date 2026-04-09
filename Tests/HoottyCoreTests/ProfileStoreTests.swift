import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct ProfileStoreTests {
    private func makeTempStore() -> ProfileStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-profile-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ProfileStore(rootDirectory: dir)
    }

    @Test func metadataRoundTrip() {
        let store = makeTempStore()
        let p = Profile(name: "Default")
        let metadata = ProfilesMetadata(activeProfileID: p.id, profiles: [p])

        store.saveMetadata(metadata)
        let loaded = store.loadMetadata()

        #expect(loaded != nil)
        #expect(loaded?.profiles.count == 1)
        #expect(loaded?.profiles[0].name == "Default")
        #expect(loaded?.activeProfileID == p.id)
    }

    @Test func loadMetadataReturnsNilWhenMissing() {
        let store = makeTempStore()
        #expect(store.loadMetadata() == nil)
    }

    @Test func profileDirectoryCreation() {
        let store = makeTempStore()
        let id = UUID()
        store.createProfileDirectory(id: id)

        let dir = store.profileDirectory(for: id)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)

        // Default config should be seeded
        let configPath = dir.appendingPathComponent("config").path
        #expect(FileManager.default.fileExists(atPath: configPath))
    }

    @Test func profileDirectoryDeletion() {
        let store = makeTempStore()
        let id = UUID()
        store.createProfileDirectory(id: id)

        let dir = store.profileDirectory(for: id)
        #expect(FileManager.default.fileExists(atPath: dir.path))

        store.deleteProfileDirectory(id: id)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test func workspaceStoreFactory() {
        let store = makeTempStore()
        let id = UUID()
        store.createProfileDirectory(id: id)

        let ws = store.workspaceStore(for: id)
        // Should be able to save and load without error
        let snapshot = WorkspaceSnapshot(workspaces: [], selectedWorkspaceID: nil)
        ws.save(snapshot)
        let loaded = ws.load()
        // Empty workspaces returns nil per WorkspaceStore.load() logic
        #expect(loaded == nil)
    }

    @Test func configFileFactory() {
        let store = makeTempStore()
        let id = UUID()
        store.createProfileDirectory(id: id)

        let config = store.configFile(for: id)
        // Default config was seeded, so theme should be present
        #expect(config.get("theme") == "Catppuccin Mocha")
    }
}
