import Testing
import Foundation
@testable import HoottyCore

@Suite struct AppModelTests {
    private func makeModel() -> AppModel {
        let wsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
        return AppModel(workspaceStore: WorkspaceStore(fileURL: wsURL), configFile: ConfigFile(fileURL: cfgURL))
    }

    @Test func removeWorkspaceByIDNoOpForUnknownID() {
        let model = makeModel()
        model.removeWorkspace(id: UUID())
        #expect(model.workspaces.count == 1)
    }

    @Test func handlePaneAttentionIgnoresFocusedPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let pane = workspace.allPanes[0]
        model.selectedWorkspaceID = workspace.id
        // pane is the only one and focused
        model.handlePaneNeedsAttention(pane.id, kind: .input)
        #expect(pane.attentionKind == nil)
    }

    @Test func moveWorkspaceSameIndexNoOp() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        let third = model.addWorkspace()
        // Move second to index 1 (same position) — no-op
        model.moveWorkspace(id: second.id, toIndex: 1)
        #expect(model.workspaces.map(\.id) == [first.id, second.id, third.id])
    }

    @Test func moveWorkspaceInvalidIDNoOp() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.moveWorkspace(id: UUID(), toIndex: 0)
        #expect(model.workspaces.map(\.id) == [first.id, second.id])
    }
}
