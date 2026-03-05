import Testing
import Foundation
@testable import KlaudeCore

@Suite struct AppModelTests {
    @Test func initCreatesOneDefaultWorkspace() {
        let model = AppModel()
        #expect(model.workspaces.count == 1)
        #expect(model.selectedWorkspaceID == model.workspaces.first?.id)
    }

    @Test func addWorkspaceIncrementsAndAppends() {
        let model = AppModel()
        let second = model.addWorkspace()
        #expect(model.workspaces.count == 2)
        #expect(second.name == "Workspace 2")
    }

    @Test func addWorkspaceNamesSequentially() {
        let model = AppModel()
        _ = model.addWorkspace()
        let third = model.addWorkspace()
        #expect(third.name == "Workspace 3")
    }

    @Test func removeWorkspaceRemovesCorrectWorkspace() {
        let model = AppModel()
        let second = model.addWorkspace()
        let secondID = second.id
        model.removeWorkspace(at: IndexSet(integer: 0))
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces.first?.id == secondID)
    }

    @Test func removeWorkspaceByIDRemovesCorrectWorkspace() {
        let model = AppModel()
        let firstID = model.workspaces.first!.id
        let second = model.addWorkspace()
        model.removeWorkspace(id: firstID)
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces.first?.id == second.id)
    }

    @Test func removeWorkspaceByIDNoOpForUnknownID() {
        let model = AppModel()
        model.removeWorkspace(id: UUID())
        #expect(model.workspaces.count == 1)
    }

    @Test func toggleSidebarFlipsVisibility() {
        let model = AppModel()
        #expect(model.sidebarVisible == true)
        model.toggleSidebar()
        #expect(model.sidebarVisible == false)
        model.toggleSidebar()
        #expect(model.sidebarVisible == true)
    }

    @Test func selectedWorkspaceReturnsCorrectWorkspace() {
        let model = AppModel()
        let first = model.workspaces.first!
        #expect(model.selectedWorkspace?.id == first.id)
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id
        #expect(model.selectedWorkspace?.id == second.id)
    }
}
