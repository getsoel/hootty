import Testing
import Foundation
@testable import KlaudeCore

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
        // Remove first tab, selection should move to second (now first)
        let firstID = workspace.tabs.first!.id
        workspace.removeTab(id: firstID)
        #expect(workspace.tabs.count == 1)
        #expect(workspace.selectedTabID == second.id)
    }

    @Test func removeLastTabCreatesNew() {
        let workspace = Workspace(name: "Test")
        let onlyTabID = workspace.tabs.first!.id
        workspace.removeTab(id: onlyTabID)
        #expect(workspace.tabs.count == 1)
        #expect(workspace.tabs.first?.id != onlyTabID)
        #expect(workspace.selectedTabID == workspace.tabs.first?.id)
    }

    @Test func isRunningReflectsTabState() {
        let workspace = Workspace(name: "Test")
        #expect(workspace.isRunning == true)
        workspace.tabs.first!.isRunning = false
        #expect(workspace.isRunning == false)
        let second = workspace.addTab()
        #expect(workspace.isRunning == true)
        second.isRunning = false
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
        // Move tab1 past tab3: [tab1, tab2, tab3] → [tab2, tab3, tab1]
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

    @Test func moveTabUnknownIDIsNoOp() {
        let workspace = Workspace(name: "Test")
        _ = workspace.addTab()
        let originalOrder = workspace.tabs.map(\.id)
        workspace.moveTab(fromID: UUID(), toID: workspace.tabs[0].id)
        #expect(workspace.tabs.map(\.id) == originalOrder)
        workspace.moveTab(fromID: workspace.tabs[0].id, toID: UUID())
        #expect(workspace.tabs.map(\.id) == originalOrder)
    }
}
