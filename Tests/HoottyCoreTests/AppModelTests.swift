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

    @Test func handlePaneAttentionFlagsBackgroundPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let group = workspace.allPaneGroups[0]
        let pane1 = group.panes[0]
        let pane2 = group.addPane()
        // pane2 is selected, signal attention for pane1
        model.selectedWorkspaceID = workspace.id
        model.handlePaneNeedsAttention(pane1.id)
        #expect(pane1.needsAttention == true)
        _ = pane2
    }

    @Test func handlePaneAttentionIgnoresFocusedPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let group = workspace.allPaneGroups[0]
        let pane = group.panes[0]
        model.selectedWorkspaceID = workspace.id
        // pane is the only one and focused
        model.handlePaneNeedsAttention(pane.id)
        #expect(pane.needsAttention == false)
    }

    @Test func handlePaneAttentionFlagsInBackgroundGroup() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let group1 = workspace.allPaneGroups[0]
        let pane1 = group1.panes[0]
        _ = workspace.splitFocusedGroup(direction: .horizontal) // group2 is now focused
        model.selectedWorkspaceID = workspace.id
        model.handlePaneNeedsAttention(pane1.id)
        #expect(pane1.needsAttention == true)
    }

    @Test func selectedWorkspaceReturnsCorrectWorkspace() {
        let model = makeModel()
        let first = model.workspaces.first!
        #expect(model.selectedWorkspace?.id == first.id)
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id
        #expect(model.selectedWorkspace?.id == second.id)
    }

    @Test func findPaneReturnsWorkspaceGroupAndPane() {
        let model = makeModel()
        let workspace = model.workspaces[0]
        let group = workspace.allPaneGroups[0]
        let pane = group.panes[0]
        let result = model.findPane(id: pane.id)
        #expect(result?.0.id == workspace.id)
        #expect(result?.1.id == group.id)
        #expect(result?.2.id == pane.id)
    }

    @Test func findPaneReturnsNilForUnknownID() {
        let model = makeModel()
        let result = model.findPane(id: UUID())
        #expect(result == nil)
    }
}
