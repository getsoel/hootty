import Testing
import Foundation
@testable import KlaudeCore

@Suite struct TabTests {
    @Test func initCreatesSinglePane() {
        let tab = Tab(name: "Test")
        #expect(tab.allPanes.count == 1)
        #expect(tab.focusedPaneID == tab.allPanes.first?.id)
    }

    @Test func defaultShellIsZsh() {
        let tab = Tab(name: "Test")
        #expect(tab.shell == "/bin/zsh")
    }

    @Test func defaultWorkingDirectoryIsHome() {
        let tab = Tab(name: "Test")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(tab.workingDirectory == home)
    }

    @Test func customInitValuesPreserved() {
        let tab = Tab(name: "Custom", shell: "/bin/bash", workingDirectory: "/tmp")
        #expect(tab.name == "Custom")
        #expect(tab.shell == "/bin/bash")
        #expect(tab.workingDirectory == "/tmp")
    }

    @Test func isRunningAggregatesPanes() {
        let tab = Tab(name: "Test")
        #expect(tab.isRunning == true)
        tab.allPanes.first!.isRunning = false
        #expect(tab.isRunning == false)
    }

    @Test func needsAttentionAggregatesPanes() {
        let tab = Tab(name: "Test")
        #expect(tab.needsAttention == false)
        tab.allPanes.first!.needsAttention = true
        #expect(tab.needsAttention == true)
    }

    @Test func splitPaneCreatesNewPane() {
        let tab = Tab(name: "Test")
        let originalPaneID = tab.allPanes.first!.id
        let newPane = tab.splitPane(paneID: originalPaneID, direction: .horizontal)
        #expect(newPane != nil)
        #expect(tab.allPanes.count == 2)
        #expect(tab.focusedPaneID == newPane?.id)
    }

    @Test func splitPaneInvalidIDReturnsNil() {
        let tab = Tab(name: "Test")
        let result = tab.splitPane(paneID: UUID(), direction: .horizontal)
        #expect(result == nil)
        #expect(tab.allPanes.count == 1)
    }

    @Test func removePaneUpdatesCount() {
        let tab = Tab(name: "Test")
        let paneID = tab.allPanes.first!.id
        let newPane = tab.splitPane(paneID: paneID, direction: .horizontal)!
        tab.removePane(id: newPane.id)
        #expect(tab.allPanes.count == 1)
        #expect(tab.allPanes.first?.id == paneID)
    }

    @Test func removePaneNoOpOnLastPane() {
        let tab = Tab(name: "Test")
        let paneID = tab.allPanes.first!.id
        tab.removePane(id: paneID)
        #expect(tab.allPanes.count == 1)
    }

    @Test func removeFocusedPaneUpdatesFocus() {
        let tab = Tab(name: "Test")
        let pane1ID = tab.allPanes.first!.id
        let pane2 = tab.splitPane(paneID: pane1ID, direction: .horizontal)!
        #expect(tab.focusedPaneID == pane2.id)
        tab.removePane(id: pane2.id)
        #expect(tab.focusedPaneID == pane1ID)
    }

    @Test func focusPaneSetsID() {
        let tab = Tab(name: "Test")
        let pane1ID = tab.allPanes.first!.id
        let pane2 = tab.splitPane(paneID: pane1ID, direction: .horizontal)!
        tab.focusPane(id: pane1ID)
        #expect(tab.focusedPaneID == pane1ID)
        tab.focusPane(id: pane2.id)
        #expect(tab.focusedPaneID == pane2.id)
    }

    @Test func focusPaneIgnoresUnknownID() {
        let tab = Tab(name: "Test")
        let originalFocus = tab.focusedPaneID
        tab.focusPane(id: UUID())
        #expect(tab.focusedPaneID == originalFocus)
    }

    @Test func isRunningWithMultiplePanes() {
        let tab = Tab(name: "Test")
        let pane1ID = tab.allPanes.first!.id
        let pane2 = tab.splitPane(paneID: pane1ID, direction: .horizontal)!
        #expect(tab.isRunning == true)
        tab.allPanes.first!.isRunning = false
        #expect(tab.isRunning == true) // pane2 still running
        pane2.isRunning = false
        #expect(tab.isRunning == false)
    }
}
