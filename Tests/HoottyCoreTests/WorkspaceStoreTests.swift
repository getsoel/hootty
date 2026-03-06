import Testing
import Foundation
@testable import HoottyCore

@Suite struct WorkspaceStoreTests {
    // MARK: - Codable round-trips

    @Test func paneCodableRoundTrip() throws {
        let pane = Pane(name: "Test", shell: "/bin/bash", workingDirectory: "/tmp")
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(Pane.self, from: data)
        #expect(decoded.id == pane.id)
        #expect(decoded.name == "Test")
        #expect(decoded.shell == "/bin/bash")
        #expect(decoded.workingDirectory == "/tmp")
    }

    @Test func paneGroupCodableRoundTrip() throws {
        let group = PaneGroup(name: "MyGroup", shell: "/bin/zsh", workingDirectory: "/Users")
        group.addPane()
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(PaneGroup.self, from: data)
        #expect(decoded.id == group.id)
        #expect(decoded.name == "MyGroup")
        #expect(decoded.panes.count == 2)
        #expect(decoded.selectedPaneID == group.selectedPaneID)
    }

    @Test func splitNodeLeafCodableRoundTrip() throws {
        let group = PaneGroup(name: "Leaf")
        let node = SplitNode(paneGroup: group)
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(SplitNode.self, from: data)
        #expect(decoded.id == node.id)
        if case .leaf(let decodedGroup) = decoded.content {
            #expect(decodedGroup.id == group.id)
            #expect(decodedGroup.name == "Leaf")
        } else {
            Issue.record("Expected leaf node")
        }
    }

    @Test func splitNodeSplitCodableRoundTrip() throws {
        let group1 = PaneGroup(name: "Left")
        let group2 = PaneGroup(name: "Right")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(paneGroup: group1),
            second: SplitNode(paneGroup: group2),
            ratio: 0.6
        )
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(SplitNode.self, from: data)
        #expect(decoded.id == node.id)
        #expect(decoded.splitRatio == 0.6)
        if case .split(let dir, let first, let second) = decoded.content {
            #expect(dir == .horizontal)
            #expect(first.allPaneGroups().first?.name == "Left")
            #expect(second.allPaneGroups().first?.name == "Right")
        } else {
            Issue.record("Expected split node")
        }
    }

    @Test func workspaceCodableRoundTrip() throws {
        let workspace = Workspace(name: "WS1")
        workspace.addPaneToFocusedGroup()
        let data = try JSONEncoder().encode(workspace)
        let decoded = try JSONDecoder().decode(Workspace.self, from: data)
        #expect(decoded.id == workspace.id)
        #expect(decoded.name == "WS1")
        #expect(decoded.allPaneGroups.count == workspace.allPaneGroups.count)
        #expect(decoded.focusedPaneGroupID == workspace.focusedPaneGroupID)
    }

    @Test func snapshotCodableRoundTrip() throws {
        let ws = Workspace(name: "Test")
        let snapshot = WorkspaceSnapshot(workspaces: [ws], selectedWorkspaceID: ws.id)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        #expect(decoded.workspaces.count == 1)
        #expect(decoded.workspaces[0].id == ws.id)
        #expect(decoded.selectedWorkspaceID == ws.id)
    }

    // MARK: - WorkspaceStore integration

    @Test func saveAndLoad() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = WorkspaceStore(fileURL: url)
        let ws = Workspace(name: "Persisted")
        let snapshot = WorkspaceSnapshot(workspaces: [ws], selectedWorkspaceID: ws.id)
        store.save(snapshot)

        let loaded = store.load()
        #expect(loaded != nil)
        #expect(loaded?.workspaces.count == 1)
        #expect(loaded?.workspaces[0].name == "Persisted")
        #expect(loaded?.selectedWorkspaceID == ws.id)
    }

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

    // MARK: - AppModel integration

    @Test func appModelLoadsFromStore() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("workspaces.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = WorkspaceStore(fileURL: url)
        let ws = Workspace(name: "Restored")
        let snapshot = WorkspaceSnapshot(workspaces: [ws], selectedWorkspaceID: ws.id)
        store.save(snapshot)

        let model = AppModel(workspaceStore: store)
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces[0].name == "Restored")
        #expect(model.selectedWorkspaceID == ws.id)
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
