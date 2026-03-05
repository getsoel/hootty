import Testing
import Foundation
@testable import PrompttyCore

@Suite struct WorkspaceTests {
    @Test func initCreatesOneTab() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.tabs.count == 1)
        #expect(workspace.selectedTabID == workspace.tabs.first?.id)
    }

    @Test func addTabIncrementsAndAppends() {
        let workspace = Workspace(name: "Test")
        let second = workspace.addTab()
        #expect(workspace.tabs.count == 2)
        #expect(second.name == "Tab 2")
    }

    @Test func addTabAutoSelects() {
        let workspace = Workspace(name: "Test")
        let second = workspace.addTab()
        #expect(workspace.selectedTabID == second.id)
    }

    @Test func removeTabUpdatesSelection() {
        let workspace = Workspace(name: "Test")
        let second = workspace.addTab()
        let firstID = workspace.tabs.first!.id
        workspace.removeTab(id: firstID)
        #expect(workspace.tabs.count == 1)
        #expect(workspace.selectedTabID == second.id)
    }

    @Test func removeLastTabLeavesEmpty() {
        let workspace = Workspace(name: "Test")
        let onlyTabID = workspace.tabs.first!.id
        workspace.removeTab(id: onlyTabID)
        #expect(workspace.tabs.isEmpty)
        #expect(workspace.selectedTabID == nil)
    }

    @Test func isRunningReflectsTabState() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.isRunning == true)
        workspace.tabs.first!.allPanes.first!.isRunning = false
        #expect(workspace.isRunning == false)
        let second = workspace.addTab()
        #expect(workspace.isRunning == true)
        second.allPanes.first!.isRunning = false
        #expect(workspace.isRunning == false)
    }

    @Test func selectTabChangesID() {
        let workspace = Workspace(name: "Test")
        let firstID = workspace.tabs.first!.id
        let second = workspace.addTab()
        #expect(workspace.selectedTabID == second.id)
        workspace.selectTab(id: firstID)
        #expect(workspace.selectedTabID == firstID)
    }

    @Test func selectTabIgnoresUnknownID() {
        let workspace = Workspace(name: "Test")
        let currentID = workspace.selectedTabID
        workspace.selectTab(id: UUID())
        #expect(workspace.selectedTabID == currentID)
    }

    @Test func moveTabReorders() {
        let workspace = Workspace(name: "Test")
        let tab1 = workspace.tabs[0]
        let tab2 = workspace.addTab()
        let tab3 = workspace.addTab()
        workspace.moveTab(fromID: tab1.id, toID: tab3.id)
        #expect(workspace.tabs.map(\.id) == [tab2.id, tab3.id, tab1.id])
    }

    @Test func moveTabSameIDIsNoOp() {
        let workspace = Workspace(name: "Test")
        let tab1 = workspace.tabs[0]
        _ = workspace.addTab()
        let originalOrder = workspace.tabs.map(\.id)
        workspace.moveTab(fromID: tab1.id, toID: tab1.id)
        #expect(workspace.tabs.map(\.id) == originalOrder)
    }

    @Test func hasAttentionTabFalseWhenNone() {
        let workspace = Workspace(name: "Test")
        _ = workspace.addTab()
        #expect(workspace.hasAttentionTab == false)
    }

    @Test func hasAttentionTabTrueForUnselectedTab() {
        let workspace = Workspace(name: "Test")
        let first = workspace.tabs[0]
        let second = workspace.addTab()
        #expect(workspace.selectedTabID == second.id)
        first.allPanes.first!.needsAttention = true
        #expect(workspace.hasAttentionTab == true)
    }

    @Test func hasAttentionTabIgnoresSelectedTab() {
        let workspace = Workspace(name: "Test")
        let first = workspace.tabs[0]
        first.allPanes.first!.needsAttention = true
        #expect(workspace.hasAttentionTab == false)
    }

    @Test func selectTabClearsNeedsAttention() {
        let workspace = Workspace(name: "Test")
        let first = workspace.tabs[0]
        let second = workspace.addTab()
        first.allPanes.first!.needsAttention = true
        #expect(first.needsAttention == true)
        workspace.selectTab(id: first.id)
        #expect(first.needsAttention == false)
        _ = second
    }

    @Test func moveTabUnknownIDIsNoOp() {
        let workspace = Workspace(name: "Test")
        _ = workspace.addTab()
        let originalOrder = workspace.tabs.map(\.id)
        workspace.moveTab(fromID: UUID(), toID: workspace.tabs[0].id)
        #expect(workspace.tabs.map(\.id) == originalOrder)
        workspace.moveTab(fromID: workspace.tabs[0].id, toID: UUID())
        #expect(workspace.tabs.map(\.id) == originalOrder)
    }

    @Test func findPaneReturnsCorrectTabAndPane() {
        let workspace = Workspace(name: "Test")
        let tab = workspace.tabs[0]
        let pane = tab.allPanes[0]
        let result = workspace.findPane(id: pane.id)
        #expect(result?.0.id == tab.id)
        #expect(result?.1.id == pane.id)
    }

    @Test func findPaneReturnsNilForUnknownID() {
        let workspace = Workspace(name: "Test")
        let result = workspace.findPane(id: UUID())
        #expect(result == nil)
    }
}
