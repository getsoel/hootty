import Testing
import Foundation
@testable import KlaudeCore

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

    @Test func handlePaneAttentionFlagsBackgroundPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let tab = workspace.tabs[0]
        let pane1 = tab.allPanes[0]
        let pane2 = tab.splitPane(paneID: pane1.id, direction: .horizontal)!
        // pane2 is focused, signal attention for pane1
        model.selectedWorkspaceID = workspace.id
        model.viewMode = .terminal
        model.handlePaneNeedsAttention(pane1.id)
        #expect(pane1.needsAttention == true)
        _ = pane2
    }

    @Test func handlePaneAttentionIgnoresFocusedPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let tab = workspace.tabs[0]
        let pane = tab.allPanes[0]
        model.selectedWorkspaceID = workspace.id
        model.viewMode = .terminal
        // pane is the only one and focused
        model.handlePaneNeedsAttention(pane.id)
        #expect(pane.needsAttention == false)
    }

    @Test func handlePaneAttentionFlagsInKanbanMode() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let tab = workspace.tabs[0]
        let pane = tab.allPanes[0]
        model.selectedWorkspaceID = workspace.id
        model.viewMode = .kanban
        model.handlePaneNeedsAttention(pane.id)
        #expect(pane.needsAttention == true)
    }

    @Test func handlePaneAttentionFlagsInBackgroundTab() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let tab1 = workspace.tabs[0]
        let tab2 = workspace.addTab()
        let pane1 = tab1.allPanes[0]
        model.selectedWorkspaceID = workspace.id
        model.viewMode = .terminal
        // tab2 is selected, tab1 is background
        model.handlePaneNeedsAttention(pane1.id)
        #expect(pane1.needsAttention == true)
        _ = tab2
    }

    @Test func selectedWorkspaceReturnsCorrectWorkspace() {
        let model = makeModel()
        let first = model.workspaces.first!
        #expect(model.selectedWorkspace?.id == first.id)
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id
        #expect(model.selectedWorkspace?.id == second.id)
    }
}
