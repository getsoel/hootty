import Testing
import Foundation
@testable import HoottyCore

@Suite struct AppModelTests {
    private func makeModel() -> AppModel {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        return AppModel(workspaceStore: WorkspaceStore(fileURL: url))
    }

    @Test func initCreatesOneDefaultWorkspace() {
        let model = makeModel()
        #expect(model.workspaces.count == 1)
        #expect(model.selectedWorkspaceID == model.workspaces.first?.id)
    }

    @Test func addWorkspaceIncrementsAndAppends() {
        let model = makeModel()
        let second = model.addWorkspace()
        #expect(model.workspaces.count == 2)
        #expect(second.name == "Workspace 2")
    }

    @Test func addWorkspaceNamesSequentially() {
        let model = makeModel()
        _ = model.addWorkspace()
        let third = model.addWorkspace()
        #expect(third.name == "Workspace 3")
    }

    @Test func removeWorkspaceRemovesCorrectWorkspace() {
        let model = makeModel()
        let second = model.addWorkspace()
        let secondID = second.id
        model.removeWorkspace(at: IndexSet(integer: 0))
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces.first?.id == secondID)
    }

    @Test func removeWorkspaceByIDRemovesCorrectWorkspace() {
        let model = makeModel()
        let firstID = model.workspaces.first!.id
        let second = model.addWorkspace()
        model.removeWorkspace(id: firstID)
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces.first?.id == second.id)
    }

    @Test func removeWorkspaceByIDNoOpForUnknownID() {
        let model = makeModel()
        model.removeWorkspace(id: UUID())
        #expect(model.workspaces.count == 1)
    }

    @Test func toggleSidebarFlipsVisibility() {
        let model = makeModel()
        #expect(model.sidebarVisible == true)
        model.toggleSidebar()
        #expect(model.sidebarVisible == false)
        model.toggleSidebar()
        #expect(model.sidebarVisible == true)
    }

    @Test func handlePaneAttentionFlagsUnfocusedPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let pane1 = workspace.allPanes[0]
        _ = workspace.splitFocusedPane(direction: .horizontal) // pane2 is now focused
        model.selectedWorkspaceID = workspace.id
        model.handlePaneNeedsAttention(pane1.id, kind: .input)
        #expect(pane1.attentionKind == .input)
    }

    @Test func handlePaneAttentionIdleKind() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let pane1 = workspace.allPanes[0]
        _ = workspace.splitFocusedPane(direction: .horizontal)
        model.selectedWorkspaceID = workspace.id
        model.handlePaneNeedsAttention(pane1.id, kind: .idle)
        #expect(pane1.attentionKind == .idle)
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

    @Test func selectedWorkspaceReturnsCorrectWorkspace() {
        let model = makeModel()
        let first = model.workspaces.first!
        #expect(model.selectedWorkspace?.id == first.id)
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id
        #expect(model.selectedWorkspace?.id == second.id)
    }

    @Test func findPaneReturnsWorkspaceAndPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let pane = workspace.allPanes[0]
        let result = model.findPane(id: pane.id)
        #expect(result?.0.id == workspace.id)
        #expect(result?.1.id == pane.id)
    }

    @Test func findPaneReturnsNilForUnknownID() {
        let model = makeModel()
        let result = model.findPane(id: UUID())
        #expect(result == nil)
    }

    @Test func handlePaneThinkingStartSetsThinking() {
        let model = makeModel()
        let pane = model.workspaces[0].allPanes[0]
        model.handlePaneThinkingChanged(pane.id, isThinking: true)
        #expect(pane.isThinking == true)
    }

    @Test func handlePaneThinkingStartClearsAttention() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let pane1 = workspace.allPanes[0]
        _ = workspace.splitFocusedPane(direction: .horizontal)
        model.selectedWorkspaceID = workspace.id
        // Set attention on unfocused pane
        model.handlePaneNeedsAttention(pane1.id, kind: .idle)
        #expect(pane1.attentionKind == .idle)
        // Thinking start should clear attention
        model.handlePaneThinkingChanged(pane1.id, isThinking: true)
        #expect(pane1.attentionKind == nil)
    }

    @Test func handlePaneThinkingStopClearsThinking() {
        let model = makeModel()
        let pane = model.workspaces[0].allPanes[0]
        model.handlePaneThinkingChanged(pane.id, isThinking: true)
        #expect(pane.isThinking == true)
        model.handlePaneThinkingChanged(pane.id, isThinking: false)
        #expect(pane.isThinking == false)
    }

    // MARK: - moveWorkspace

    @Test func moveWorkspaceDown() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        let third = model.addWorkspace()
        // Move first to after third (toIndex=3)
        model.moveWorkspace(id: first.id, toIndex: 3)
        #expect(model.workspaces.map(\.id) == [second.id, third.id, first.id])
    }

    @Test func moveWorkspaceUp() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        let third = model.addWorkspace()
        // Move third to before first (toIndex=0)
        model.moveWorkspace(id: third.id, toIndex: 0)
        #expect(model.workspaces.map(\.id) == [third.id, first.id, second.id])
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

    @Test func moveWorkspacePersistsOrder() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = WorkspaceStore(fileURL: url)
        let model = AppModel(workspaceStore: store)
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        let third = model.addWorkspace()
        model.moveWorkspace(id: third.id, toIndex: 0)
        // Reload from same store
        let reloaded = AppModel(workspaceStore: WorkspaceStore(fileURL: url))
        #expect(reloaded.workspaces.map(\.id) == [third.id, first.id, second.id])
    }
}
