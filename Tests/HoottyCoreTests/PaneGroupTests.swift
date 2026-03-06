import Testing
import Foundation
@testable import HoottyCore

@Suite struct PaneGroupTests {
    @Test func initCreatesSinglePane() {
        let group = PaneGroup(name: "Test")
        #expect(group.panes.count == 1)
        #expect(group.selectedPaneID == group.panes.first?.id)
    }

    @Test func addPaneIncrementsAndAppends() {
        let group = PaneGroup(name: "Test")
        let second = group.addPane()
        #expect(group.panes.count == 2)
        #expect(second.name == "Pane 2")
        #expect(group.selectedPaneID == second.id)
    }

    @Test func removePaneUpdatesSelection() {
        let group = PaneGroup(name: "Test")
        let second = group.addPane()
        let firstID = group.panes.first!.id
        group.removePane(id: firstID)
        #expect(group.panes.count == 1)
        #expect(group.selectedPaneID == second.id)
    }

    @Test func removeLastPaneLeavesEmpty() {
        let group = PaneGroup(name: "Test")
        let onlyPaneID = group.panes.first!.id
        group.removePane(id: onlyPaneID)
        #expect(group.panes.isEmpty)
        #expect(group.selectedPaneID == nil)
    }

    @Test func selectPaneSetsID() {
        let group = PaneGroup(name: "Test")
        let firstID = group.panes.first!.id
        let second = group.addPane()
        #expect(group.selectedPaneID == second.id)
        group.selectPane(id: firstID)
        #expect(group.selectedPaneID == firstID)
    }

    @Test func selectPaneIgnoresUnknownID() {
        let group = PaneGroup(name: "Test")
        let currentID = group.selectedPaneID
        group.selectPane(id: UUID())
        #expect(group.selectedPaneID == currentID)
    }

    @Test func selectPaneClearsAttention() {
        let group = PaneGroup(name: "Test")
        let first = group.panes[0]
        let second = group.addPane()
        first.needsAttention = true
        group.selectPane(id: first.id)
        #expect(first.needsAttention == false)
        _ = second
    }

    @Test func movePaneReorders() {
        let group = PaneGroup(name: "Test")
        let pane1 = group.panes[0]
        let pane2 = group.addPane()
        let pane3 = group.addPane()
        group.movePane(fromID: pane1.id, toID: pane3.id)
        #expect(group.panes.map(\.id) == [pane2.id, pane3.id, pane1.id])
    }

    @Test func movePaneSameIDIsNoOp() {
        let group = PaneGroup(name: "Test")
        let pane1 = group.panes[0]
        _ = group.addPane()
        let originalOrder = group.panes.map(\.id)
        group.movePane(fromID: pane1.id, toID: pane1.id)
        #expect(group.panes.map(\.id) == originalOrder)
    }

    @Test func isRunningAggregatesPanes() {
        let group = PaneGroup(name: "Test")
        #expect(group.isRunning == true)
        group.panes.first!.isRunning = false
        #expect(group.isRunning == false)
    }

    @Test func needsAttentionAggregatesPanes() {
        let group = PaneGroup(name: "Test")
        #expect(group.needsAttention == false)
        group.panes.first!.needsAttention = true
        #expect(group.needsAttention == true)
    }

    @Test func displayNameReturnsNameWhenNoCustomName() {
        let group = PaneGroup(name: "Group 1")
        #expect(group.displayName == "Group 1")
    }

    @Test func displayNameReturnsCustomNameWhenSet() {
        let group = PaneGroup(name: "Group 1")
        group.customName = "My Terminal"
        #expect(group.displayName == "My Terminal")
    }

    @Test func displayNameRevertsWhenCustomNameCleared() {
        let group = PaneGroup(name: "Group 1")
        group.customName = "My Terminal"
        #expect(group.displayName == "My Terminal")
        group.customName = nil
        #expect(group.displayName == "Group 1")
    }

    @Test func codableRoundTripWithCustomName() throws {
        let group = PaneGroup(name: "Group 1", customName: "Custom")
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(PaneGroup.self, from: data)
        #expect(decoded.customName == "Custom")
        #expect(decoded.displayName == "Custom")
    }

    @Test func selectPreviousPaneWraps() {
        let group = PaneGroup(name: "Test")
        let pane1 = group.panes[0]
        let pane2 = group.addPane()
        let pane3 = group.addPane()
        #expect(group.selectedPaneID == pane3.id)
        group.selectPreviousPane()
        #expect(group.selectedPaneID == pane2.id)
        group.selectPreviousPane()
        #expect(group.selectedPaneID == pane1.id)
        // Wraps to last
        group.selectPreviousPane()
        #expect(group.selectedPaneID == pane3.id)
    }

    @Test func selectNextPaneWraps() {
        let group = PaneGroup(name: "Test")
        let pane1 = group.panes[0]
        let pane2 = group.addPane()
        let pane3 = group.addPane()
        group.selectPane(id: pane1.id)
        group.selectNextPane()
        #expect(group.selectedPaneID == pane2.id)
        group.selectNextPane()
        #expect(group.selectedPaneID == pane3.id)
        // Wraps to first
        group.selectNextPane()
        #expect(group.selectedPaneID == pane1.id)
    }

    @Test func selectPreviousPaneNoOpWithSinglePane() {
        let group = PaneGroup(name: "Test")
        let only = group.panes[0]
        group.selectPreviousPane()
        #expect(group.selectedPaneID == only.id)
    }

    @Test func selectNextPaneNoOpWithSinglePane() {
        let group = PaneGroup(name: "Test")
        let only = group.panes[0]
        group.selectNextPane()
        #expect(group.selectedPaneID == only.id)
    }

    @Test func addPaneInheritsWorkingDirectory() {
        let group = PaneGroup(name: "Test", workingDirectory: "/tmp")
        let second = group.addPane()
        #expect(second.workingDirectory == "/tmp")
    }
}
