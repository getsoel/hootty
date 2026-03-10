import Testing
import Foundation
@testable import HoottyCore

@Suite struct WorkspaceStoreTests {
    @Test func loadMissingFileReturnsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-nonexistent-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        let store = WorkspaceStore(fileURL: url)
        #expect(store.load() == nil)
    }

    @Test func loadCorruptDataReturnsNil() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        try "not json".data(using: .utf8)!.write(to: url)
        let store = WorkspaceStore(fileURL: url)
        #expect(store.load() == nil)
    }

    @Test func snapshotWithoutSidebarFieldsDecodesAsNil() throws {
        // Simulates loading an older workspaces.json that lacks sidebar fields
        let ws = Workspace(name: "Old")
        let json: [String: Any] = [
            "workspaces": [try JSONSerialization.jsonObject(with: JSONEncoder().encode(ws))],
            "selectedWorkspaceID": ws.id.uuidString
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        #expect(decoded.sidebarWidth == nil)
        #expect(decoded.sidebarVisible == nil)
    }

    @Test func appModelDefaultsSidebarWhenNotPersisted() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = WorkspaceStore(fileURL: url)
        let ws = Workspace(name: "NoSidebar")
        let snapshot = WorkspaceSnapshot(workspaces: [ws], selectedWorkspaceID: ws.id)
        store.save(snapshot)

        let model = AppModel(workspaceStore: store)
        #expect(model.sidebarWidth == 200)
        #expect(model.sidebarVisible == true)
    }

    @Test func appModelFallsBackToDefault() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        let store = WorkspaceStore(fileURL: url)
        let model = AppModel(workspaceStore: store)
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces[0].name == "Workspace 1")
    }
}
