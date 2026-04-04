import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct WorkspaceStoreTests {
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

        try Data("not json".utf8).write(to: url)
        let store = WorkspaceStore(fileURL: url)
        #expect(store.load() == nil)
    }

    @Test func snapshotWithoutSidebarFieldsDecodesAsNil() throws {
        // Simulates loading an older workspaces.json that lacks sidebar fields
        let ws = Workspace(name: "Old")
        let json: [String: Any] = try [
            "workspaces": [JSONSerialization.jsonObject(with: JSONEncoder().encode(ws))],
            "selectedWorkspaceID": ws.id.uuidString
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        #expect(decoded.sidebarWidth == nil)
        #expect(decoded.sidebarMode == nil)
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
        #expect(model.sidebarWidth == 260)
        #expect(model.sidebarMode == .full)
    }

    @Test func toggleSidebarCyclesFullCondensedHidden() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = WorkspaceStore(fileURL: url)
        let model = AppModel(workspaceStore: store)
        #expect(model.sidebarMode == .full)

        model.toggleSidebar()
        #expect(model.sidebarMode == .condensed)

        model.toggleSidebar()
        #expect(model.sidebarMode == .hidden)

        model.toggleSidebar()
        #expect(model.sidebarMode == .full)
    }

    @Test func backwardCompatDecodeSidebarVisibleTrue() throws {
        let ws = Workspace(name: "Old")
        let json: [String: Any] = try [
            "workspaces": [JSONSerialization.jsonObject(with: JSONEncoder().encode(ws))],
            "selectedWorkspaceID": ws.id.uuidString,
            "sidebarVisible": true
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        // sidebarMode not present, sidebarVisible is true
        #expect(decoded.sidebarMode == nil)
        #expect(decoded.sidebarVisible == true)

        // AppModel should map to .full
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try data.write(to: url)
        let model = AppModel(workspaceStore: WorkspaceStore(fileURL: url))
        #expect(model.sidebarMode == .full)
    }

    @Test func backwardCompatDecodeSidebarVisibleFalse() throws {
        let ws = Workspace(name: "Old")
        let json: [String: Any] = try [
            "workspaces": [JSONSerialization.jsonObject(with: JSONEncoder().encode(ws))],
            "selectedWorkspaceID": ws.id.uuidString,
            "sidebarVisible": false
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try data.write(to: url)
        let model = AppModel(workspaceStore: WorkspaceStore(fileURL: url))
        #expect(model.sidebarMode == .hidden)
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
