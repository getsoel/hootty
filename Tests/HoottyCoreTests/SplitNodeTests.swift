import Testing
import Foundation
@testable import HoottyCore

@Suite struct SplitNodeTests {
    @Test func leafHasOnePane() {
        let pane = Pane(name: "Test")
        let node = SplitNode(pane: pane)
        #expect(node.allPanes().count == 1)
        #expect(node.allPanes().first?.id == pane.id)
    }

    @Test func splitCreatesTwoChildren() {
        let pane = Pane(name: "Original")
        let node = SplitNode(pane: pane)
        let newPane = Pane(name: "New")
        let result = node.split(paneID: pane.id, direction: .horizontal, newPane: newPane)
        #expect(result == true)
        #expect(node.allPanes().count == 2)
        #expect(node.allPanes().map(\.id).contains(pane.id))
        #expect(node.allPanes().map(\.id).contains(newPane.id))
    }

    @Test func splitPreservesOrder() {
        let pane = Pane(name: "Original")
        let node = SplitNode(pane: pane)
        let newPane = Pane(name: "New")
        node.split(paneID: pane.id, direction: .horizontal, newPane: newPane)
        let panes = node.allPanes()
        #expect(panes[0].id == pane.id)
        #expect(panes[1].id == newPane.id)
    }

    @Test func nestedSplit() {
        let pane1 = Pane(name: "P1")
        let node = SplitNode(pane: pane1)
        let pane2 = Pane(name: "P2")
        node.split(paneID: pane1.id, direction: .horizontal, newPane: pane2)
        let pane3 = Pane(name: "P3")
        node.split(paneID: pane2.id, direction: .vertical, newPane: pane3)
        #expect(node.allPanes().count == 3)
    }

    @Test func splitUnknownPaneReturnsFalse() {
        let pane = Pane(name: "Test")
        let node = SplitNode(pane: pane)
        let result = node.split(paneID: UUID(), direction: .horizontal, newPane: Pane(name: "New"))
        #expect(result == false)
        #expect(node.allPanes().count == 1)
    }

    @Test func removePaneCollapsesParent() {
        let pane1 = Pane(name: "P1")
        let node = SplitNode(pane: pane1)
        let pane2 = Pane(name: "P2")
        node.split(paneID: pane1.id, direction: .horizontal, newPane: pane2)
        let result = node.removePane(id: pane2.id)
        #expect(result == true)
        #expect(node.allPanes().count == 1)
        #expect(node.allPanes().first?.id == pane1.id)
    }

    @Test func removePaneNoOpOnLeaf() {
        let pane = Pane(name: "Test")
        let node = SplitNode(pane: pane)
        let result = node.removePane(id: pane.id)
        #expect(result == false)
        #expect(node.allPanes().count == 1)
    }

    @Test func removeFromNestedSplit() {
        let pane1 = Pane(name: "P1")
        let node = SplitNode(pane: pane1)
        let pane2 = Pane(name: "P2")
        node.split(paneID: pane1.id, direction: .horizontal, newPane: pane2)
        let pane3 = Pane(name: "P3")
        node.split(paneID: pane2.id, direction: .vertical, newPane: pane3)
        // Remove pane2 from nested split — pane3 should promote up
        let result = node.removePane(id: pane2.id)
        #expect(result == true)
        #expect(node.allPanes().count == 2)
        #expect(node.allPanes().map(\.id).contains(pane1.id))
        #expect(node.allPanes().map(\.id).contains(pane3.id))
    }
}
