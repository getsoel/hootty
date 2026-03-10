import Testing
import Foundation
@testable import HoottyCore

@Suite struct WorkspaceTests {
    @Test func isRunningReflectsPaneState() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.isRunning == true)
        workspace.allPanes.first!.isRunning = false
        #expect(workspace.isRunning == false)
    }

    @Test func focusPaneIgnoresUnknownID() {
        let workspace = Workspace(name: "Test")
        let currentID = workspace.focusedPaneID
        workspace.focusPane(id: UUID())
        #expect(workspace.focusedPaneID == currentID)
    }
}
