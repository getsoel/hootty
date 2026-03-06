import Testing
import Foundation
@testable import HoottyCore

@Suite struct SplitNodeTests {
    @Test func leafHasOneGroup() {
        let group = PaneGroup(name: "Test")
        let node = SplitNode(paneGroup: group)
        #expect(node.allPaneGroups().count == 1)
        #expect(node.allPaneGroups().first?.id == group.id)
        #expect(node.allPanes().count == 1)
    }

    @Test func splitCreatesTwoChildren() {
        let group = PaneGroup(name: "Original")
        let node = SplitNode(paneGroup: group)
        let newGroup = PaneGroup(name: "New")
        let result = node.splitGroup(groupID: group.id, direction: .horizontal, newGroup: newGroup)
        #expect(result == true)
        #expect(node.allPaneGroups().count == 2)
        #expect(node.allPaneGroups().map(\.id).contains(group.id))
        #expect(node.allPaneGroups().map(\.id).contains(newGroup.id))
    }

    @Test func splitPreservesOrder() {
        let group = PaneGroup(name: "Original")
        let node = SplitNode(paneGroup: group)
        let newGroup = PaneGroup(name: "New")
        node.splitGroup(groupID: group.id, direction: .horizontal, newGroup: newGroup)
        let groups = node.allPaneGroups()
        #expect(groups[0].id == group.id)
        #expect(groups[1].id == newGroup.id)
    }

    @Test func nestedSplit() {
        let group1 = PaneGroup(name: "G1")
        let node = SplitNode(paneGroup: group1)
        let group2 = PaneGroup(name: "G2")
        node.splitGroup(groupID: group1.id, direction: .horizontal, newGroup: group2)
        let group3 = PaneGroup(name: "G3")
        node.splitGroup(groupID: group2.id, direction: .vertical, newGroup: group3)
        #expect(node.allPaneGroups().count == 3)
    }

    @Test func splitUnknownGroupReturnsFalse() {
        let group = PaneGroup(name: "Test")
        let node = SplitNode(paneGroup: group)
        let result = node.splitGroup(groupID: UUID(), direction: .horizontal, newGroup: PaneGroup(name: "New"))
        #expect(result == false)
        #expect(node.allPaneGroups().count == 1)
    }

    @Test func removePaneGroupCollapsesParent() {
        let group1 = PaneGroup(name: "G1")
        let node = SplitNode(paneGroup: group1)
        let group2 = PaneGroup(name: "G2")
        node.splitGroup(groupID: group1.id, direction: .horizontal, newGroup: group2)
        let result = node.removePaneGroup(id: group2.id)
        #expect(result == true)
        #expect(node.allPaneGroups().count == 1)
        #expect(node.allPaneGroups().first?.id == group1.id)
    }

    @Test func removePaneGroupNoOpOnLeaf() {
        let group = PaneGroup(name: "Test")
        let node = SplitNode(paneGroup: group)
        let result = node.removePaneGroup(id: group.id)
        #expect(result == false)
        #expect(node.allPaneGroups().count == 1)
    }

    @Test func removeFromNestedSplit() {
        let group1 = PaneGroup(name: "G1")
        let node = SplitNode(paneGroup: group1)
        let group2 = PaneGroup(name: "G2")
        node.splitGroup(groupID: group1.id, direction: .horizontal, newGroup: group2)
        let group3 = PaneGroup(name: "G3")
        node.splitGroup(groupID: group2.id, direction: .vertical, newGroup: group3)
        let result = node.removePaneGroup(id: group2.id)
        #expect(result == true)
        #expect(node.allPaneGroups().count == 2)
        #expect(node.allPaneGroups().map(\.id).contains(group1.id))
        #expect(node.allPaneGroups().map(\.id).contains(group3.id))
    }

    @Test func findPaneGroupContainingPaneID() {
        let group = PaneGroup(name: "Test")
        let paneID = group.panes.first!.id
        let node = SplitNode(paneGroup: group)
        let found = node.findPaneGroup(containingPaneID: paneID)
        #expect(found?.id == group.id)
    }

    @Test func findPaneGroupReturnsNilForUnknown() {
        let group = PaneGroup(name: "Test")
        let node = SplitNode(paneGroup: group)
        let found = node.findPaneGroup(containingPaneID: UUID())
        #expect(found == nil)
    }

    @Test func allPanesAcrossGroups() {
        let group1 = PaneGroup(name: "G1")
        group1.addPane()
        let node = SplitNode(paneGroup: group1)
        let group2 = PaneGroup(name: "G2")
        node.splitGroup(groupID: group1.id, direction: .horizontal, newGroup: group2)
        #expect(node.allPanes().count == 3) // 2 in group1, 1 in group2
    }
}
