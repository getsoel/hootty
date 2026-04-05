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

    // MARK: - Persistent Panel

    @Test func togglePersistentPanelCreatesDefaultPane() {
        let model = TestHelpers.makeModel()
        #expect(model.persistentNode == nil)
        #expect(model.persistentPanelVisible == false)

        model.togglePersistentPanel()

        #expect(model.persistentNode != nil)
        #expect(model.persistentPanelVisible == true)
        #expect(model.persistentNode?.allPanes().count == 1)
        #expect(model.persistentFocusedPaneID != nil)
    }

    @Test func togglePersistentPanelHidesWhenVisible() {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        #expect(model.persistentPanelVisible == true)

        model.togglePersistentPanel()
        #expect(model.persistentPanelVisible == false)
        // Node is preserved (panes still exist, just hidden)
        #expect(model.persistentNode != nil)
    }

    @Test func closePersistentPanelNilsNode() {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        model.focusDomain = .persistent

        model.closePersistentPanel()

        #expect(model.persistentNode == nil)
        #expect(model.persistentPanelVisible == false)
        #expect(model.persistentFocusedPaneID == nil)
        #expect(model.focusDomain == .workspace)
    }

    @Test func persistentFocusedPaneFallsBackToFirst() throws {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        let firstPane = try #require(model.persistentNode?.firstPane())

        // With matching ID
        model.persistentFocusedPaneID = firstPane.id
        #expect(model.persistentFocusedPane?.id == firstPane.id)

        // With bogus ID, falls back to first
        model.persistentFocusedPaneID = UUID()
        #expect(model.persistentFocusedPane?.id == firstPane.id)

        // With nil, falls back to first
        model.persistentFocusedPaneID = nil
        #expect(model.persistentFocusedPane?.id == firstPane.id)
    }

    @Test func findPaneLocationSearchesPersistentNode() throws {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        let persistentPane = try #require(model.persistentNode?.firstPane())
        let workspacePane = model.workspaces[0].allPanes[0]

        // Find workspace pane
        if case let .workspace(_, pane) = model.findPaneLocation(id: workspacePane.id) {
            #expect(pane.id == workspacePane.id)
        } else {
            Issue.record("Expected workspace location")
        }

        // Find persistent pane
        if case let .persistent(pane) = model.findPaneLocation(id: persistentPane.id) {
            #expect(pane.id == persistentPane.id)
        } else {
            Issue.record("Expected persistent location")
        }

        // Unknown ID
        #expect(model.findPaneLocation(id: UUID()) == nil)
    }

    @Test func cyclePersistentFocusForward() throws {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        let pane1 = try #require(model.persistentNode?.firstPane())
        let pane2 = Pane(name: "Docked 2")
        model.persistentNode?.splitPane(paneID: pane1.id, direction: .vertical, newPane: pane2)
        model.persistentFocusedPaneID = pane1.id

        model.cyclePersistentFocus(forward: true)
        #expect(model.persistentFocusedPaneID == pane2.id)

        model.cyclePersistentFocus(forward: true)
        #expect(model.persistentFocusedPaneID == pane1.id) // wraps
    }

    @Test func cyclePersistentFocusBackward() throws {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        let pane1 = try #require(model.persistentNode?.firstPane())
        let pane2 = Pane(name: "Docked 2")
        model.persistentNode?.splitPane(paneID: pane1.id, direction: .vertical, newPane: pane2)
        model.persistentFocusedPaneID = pane1.id

        model.cyclePersistentFocus(forward: false)
        #expect(model.persistentFocusedPaneID == pane2.id) // wraps backward
    }

    @Test func focusDomainSwitchesOnPanelClose() {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        model.focusDomain = .persistent
        model.closePersistentPanel()
        #expect(model.focusDomain == .workspace)
    }

    @Test func resetWorkspacesClearsPersistentPanel() {
        let model = TestHelpers.makeModel()
        model.togglePersistentPanel()
        model.focusDomain = .persistent

        model.resetWorkspaces()

        #expect(model.persistentNode == nil)
        #expect(model.persistentPanelVisible == false)
        #expect(model.persistentPanelWidth == 400)
        #expect(model.persistentFocusedPaneID == nil)
        #expect(model.focusDomain == .workspace)
    }
}
