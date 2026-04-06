import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct AppModelTests {
    @Test func removeWorkspaceByIDNoOpForUnknownID() {
        let model = TestHelpers.makeModel()
        model.removeWorkspace(id: UUID())
        #expect(model.workspaces.count == 1)
    }

    @Test func handlePaneAttentionIgnoresFocusedPane() {
        let model = TestHelpers.makeModel()
        let workspace = model.workspaces[0]
        let pane = workspace.allPanes[0]
        model.selectedWorkspaceID = workspace.id
        // pane is the only one and focused
        model.handlePaneNeedsAttention(pane.id, kind: .bell)
        #expect(pane.attentionKind == nil)
    }

    @Test func moveWorkspaceSameIndexNoOp() {
        let model = TestHelpers.makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        let third = model.addWorkspace()
        // Move second to index 1 (same position) — no-op
        model.moveWorkspace(id: second.id, toIndex: 1)
        #expect(model.workspaces.map(\.id) == [first.id, second.id, third.id])
    }

    @Test func moveWorkspaceInvalidIDNoOp() {
        let model = TestHelpers.makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.moveWorkspace(id: UUID(), toIndex: 0)
        #expect(model.workspaces.map(\.id) == [first.id, second.id])
    }

    @Test func addWorkspaceFillsGapAfterDeletion() {
        let model = TestHelpers.makeModel()
        // Initial workspace is "Workspace 1"
        #expect(model.workspaces[0].name == "Workspace 1")
        let w2 = model.addWorkspace()
        #expect(w2.name == "Workspace 2")
        let w3 = model.addWorkspace()
        #expect(w3.name == "Workspace 3")

        // Delete "Workspace 2" — next add should fill the gap
        model.removeWorkspace(id: w2.id)
        let w2Again = model.addWorkspace()
        #expect(w2Again.name == "Workspace 2")
    }

    @Test func addWorkspaceSkipsCustomNames() {
        let model = TestHelpers.makeModel()
        // Rename the initial workspace to something custom
        model.workspaces[0].name = "My Terminal"
        let w = model.addWorkspace()
        // Should still be "Workspace 1" since no numbered workspaces exist
        #expect(w.name == "Workspace 1")
    }
}
