import Testing
import Foundation
@testable import HoottyCore

@Suite struct WorkspaceTests {
    @Test func initCreatesOnePane() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.allPanes.count == 1)
        #expect(workspace.focusedPaneID == workspace.allPanes.first?.id)
    }

    @Test func splitFocusedPaneCreatesNewPane() {
        let workspace = Workspace(name: "Test")
        let newPane = workspace.splitFocusedPane(direction: .horizontal)
        #expect(newPane != nil)
        #expect(workspace.allPanes.count == 2)
        #expect(workspace.focusedPaneID == newPane?.id)
    }

    @Test func removePaneUpdatesSelection() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPanes[0]
        let second = workspace.splitFocusedPane(direction: .horizontal)!
        workspace.removePane(id: second.id)
        #expect(workspace.allPanes.count == 1)
        #expect(workspace.focusedPaneID == first.id)
    }

    @Test func removeLastPaneCreatesNewOne() {
        let workspace = Workspace(name: "Test")
        let paneID = workspace.allPanes.first!.id
        workspace.removePane(id: paneID)
        #expect(workspace.allPanes.count == 1)
        #expect(workspace.allPanes.first?.id != paneID)
    }

    @Test func isRunningReflectsPaneState() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.isRunning == true)
        workspace.allPanes.first!.isRunning = false
        #expect(workspace.isRunning == false)
    }

    @Test func focusPaneSetsID() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPanes[0]
        let second = workspace.splitFocusedPane(direction: .horizontal)!
        #expect(workspace.focusedPaneID == second.id)
        workspace.focusPane(id: first.id)
        #expect(workspace.focusedPaneID == first.id)
    }

    @Test func focusPaneIgnoresUnknownID() {
        let workspace = Workspace(name: "Test")
        let currentID = workspace.focusedPaneID
        workspace.focusPane(id: UUID())
        #expect(workspace.focusedPaneID == currentID)
    }

    @Test func findPaneReturnsCorrectPane() {
        let workspace = Workspace(name: "Test")
        let pane = workspace.allPanes[0]
        let result = workspace.findPane(id: pane.id)
        #expect(result?.id == pane.id)
    }

    @Test func findPaneReturnsNilForUnknownID() {
        let workspace = Workspace(name: "Test")
        let result = workspace.findPane(id: UUID())
        #expect(result == nil)
    }

    @Test func hasAttentionFalseWhenNone() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.hasAttention == false)
    }

    @Test func hasAttentionTrueForUnfocusedPane() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPanes[0]
        _ = workspace.splitFocusedPane(direction: .horizontal)
        // first is now unfocused
        first.attentionKind = .input
        #expect(workspace.hasAttention == true)
        #expect(workspace.attentionKind == .input)
    }

    @Test func allPanesAcrossSplits() {
        let workspace = Workspace(name: "Test")
        _ = workspace.splitFocusedPane(direction: .horizontal)
        #expect(workspace.allPanes.count == 2)
    }

    @Test func removePaneFromSplit() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPanes[0]
        _ = workspace.splitFocusedPane(direction: .horizontal)
        #expect(workspace.allPanes.count == 2)
        workspace.removePane(id: first.id)
        #expect(workspace.allPanes.count == 1)
    }

    @Test func focusPaneClearsAttention() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPanes[0]
        _ = workspace.splitFocusedPane(direction: .horizontal)
        // first is now unfocused; flag it
        first.attentionKind = .idle
        // focusing should clear attention
        workspace.focusPane(id: first.id)
        #expect(first.attentionKind == nil)
    }
}
