import Testing
import Foundation
@testable import HoottyCore

@Suite struct WorkspaceTests {
    @Test func initCreatesOnePaneGroup() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.allPaneGroups.count == 1)
        #expect(workspace.focusedPaneGroupID == workspace.allPaneGroups.first?.id)
    }

    @Test func addPaneToFocusedGroup() {
        let workspace = Workspace(name: "Test")
        let pane = workspace.addPaneToFocusedGroup()
        #expect(pane != nil)
        #expect(workspace.focusedPaneGroup?.panes.count == 2)
    }

    @Test func splitFocusedGroupCreatesNewGroup() {
        let workspace = Workspace(name: "Test")
        let newGroup = workspace.splitFocusedGroup(direction: .horizontal)
        #expect(newGroup != nil)
        #expect(workspace.allPaneGroups.count == 2)
        #expect(workspace.focusedPaneGroupID == newGroup?.id)
    }

    @Test func removePaneGroupUpdatesSelection() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPaneGroups[0]
        let second = workspace.splitFocusedGroup(direction: .horizontal)!
        workspace.removePaneGroup(id: second.id)
        #expect(workspace.allPaneGroups.count == 1)
        #expect(workspace.focusedPaneGroupID == first.id)
    }

    @Test func removeLastGroupCreatesNewOne() {
        let workspace = Workspace(name: "Test")
        let groupID = workspace.allPaneGroups.first!.id
        workspace.removePaneGroup(id: groupID)
        #expect(workspace.allPaneGroups.count == 1)
        #expect(workspace.allPaneGroups.first?.id != groupID)
    }

    @Test func isRunningReflectsGroupState() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.isRunning == true)
        workspace.allPanes.first!.isRunning = false
        #expect(workspace.isRunning == false)
    }

    @Test func focusPaneGroupSetsID() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPaneGroups[0]
        let second = workspace.splitFocusedGroup(direction: .horizontal)!
        #expect(workspace.focusedPaneGroupID == second.id)
        workspace.focusPaneGroup(id: first.id)
        #expect(workspace.focusedPaneGroupID == first.id)
    }

    @Test func focusPaneGroupIgnoresUnknownID() {
        let workspace = Workspace(name: "Test")
        let currentID = workspace.focusedPaneGroupID
        workspace.focusPaneGroup(id: UUID())
        #expect(workspace.focusedPaneGroupID == currentID)
    }

    @Test func focusPaneFindsGroupAndSelectsPane() {
        let workspace = Workspace(name: "Test")
        let group = workspace.allPaneGroups[0]
        let pane1 = group.panes[0]
        let pane2 = group.addPane()
        #expect(group.selectedPaneID == pane2.id)
        workspace.focusPane(id: pane1.id)
        #expect(group.selectedPaneID == pane1.id)
    }

    @Test func findPaneReturnsCorrectGroupAndPane() {
        let workspace = Workspace(name: "Test")
        let group = workspace.allPaneGroups[0]
        let pane = group.panes[0]
        let result = workspace.findPane(id: pane.id)
        #expect(result?.0.id == group.id)
        #expect(result?.1.id == pane.id)
    }

    @Test func findPaneReturnsNilForUnknownID() {
        let workspace = Workspace(name: "Test")
        let result = workspace.findPane(id: UUID())
        #expect(result == nil)
    }

    @Test func hasAttentionGroupFalseWhenNone() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.hasAttentionGroup == false)
    }

    @Test func hasAttentionGroupTrueForUnfocusedGroup() {
        let workspace = Workspace(name: "Test")
        let first = workspace.allPaneGroups[0]
        _ = workspace.splitFocusedGroup(direction: .horizontal)
        // first is now unfocused
        first.panes.first!.needsAttention = true
        #expect(workspace.hasAttentionGroup == true)
    }

    @Test func allPanesAcrossGroups() {
        let workspace = Workspace(name: "Test")
        workspace.addPaneToFocusedGroup()
        _ = workspace.splitFocusedGroup(direction: .horizontal)
        #expect(workspace.allPanes.count == 3) // 2 in first group, 1 in new group
    }

    @Test func closePaneRemovesPaneFromGroup() {
        let workspace = Workspace(name: "Test")
        let group = workspace.allPaneGroups[0]
        let pane1 = group.panes[0]
        let pane2 = group.addPane()
        workspace.closePane(id: pane1.id)
        #expect(group.panes.count == 1)
        #expect(group.panes.first?.id == pane2.id)
    }

    @Test func closePaneRemovesGroupWhenLastPane() {
        let workspace = Workspace(name: "Test")
        _ = workspace.splitFocusedGroup(direction: .horizontal)
        let groups = workspace.allPaneGroups
        #expect(groups.count == 2)
        let groupToClose = groups[0]
        let paneID = groupToClose.panes.first!.id
        workspace.closePane(id: paneID)
        #expect(workspace.allPaneGroups.count == 1)
    }
}
