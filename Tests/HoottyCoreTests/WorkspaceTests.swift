import Testing
import Foundation
@testable import HoottyCore

@Suite struct WorkspaceTests {
    @Test func singlePaneByDefault() {
        let ws = Workspace(name: "Test")
        #expect(ws.allPanes.count == 1)
        #expect(ws.focusedPane != nil)
        #expect(ws.focusedPaneID == ws.allPanes[0].id)
    }

    @Test func isRunningReflectsPaneState() {
        let ws = Workspace(name: "Test")
        #expect(ws.isRunning == true)
        ws.allPanes.first!.isRunning = false
        #expect(ws.isRunning == false)
    }

    @Test func focusPaneIgnoresUnknownID() {
        let ws = Workspace(name: "Test")
        let currentID = ws.focusedPaneID
        ws.focusPane(id: UUID())
        #expect(ws.focusedPaneID == currentID)
    }

    @Test func findPaneFindsExistingPane() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        #expect(ws.findPane(id: p1.id) != nil)
        #expect(ws.findPane(id: UUID()) == nil)
    }

    @Test func attentionOnUnfocusedPane() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        // p2 is now focused; set attention on p1
        p1.attentionKind = .bell
        #expect(ws.attentionKind == .bell)
    }

    // MARK: - Directional Focus

    @Test func directionalFocusHorizontalSplit() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        ws.focusPane(id: p1.id)

        ws.focusPaneInDirection(.right)
        #expect(ws.focusedPaneID == p2.id)

        ws.focusPaneInDirection(.left)
        #expect(ws.focusedPaneID == p1.id)

        ws.focusPaneInDirection(.up)
        #expect(ws.focusedPaneID == p1.id)
        ws.focusPaneInDirection(.down)
        #expect(ws.focusedPaneID == p1.id)
    }

    @Test func directionalFocusVerticalSplit() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .vertical)!
        ws.focusPane(id: p1.id)

        ws.focusPaneInDirection(.down)
        #expect(ws.focusedPaneID == p2.id)

        ws.focusPaneInDirection(.up)
        #expect(ws.focusedPaneID == p1.id)

        ws.focusPaneInDirection(.left)
        #expect(ws.focusedPaneID == p1.id)
        ws.focusPaneInDirection(.right)
        #expect(ws.focusedPaneID == p1.id)
    }

    @Test func directionalFocusSinglePaneNoOp() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        for dir in FocusDirection.allCases {
            ws.focusPaneInDirection(dir)
            #expect(ws.focusedPaneID == p1.id)
        }
    }

    @Test func directionalFocus2x2Grid() {
        let pA = Pane(name: "A")
        let pB = Pane(name: "B")
        let pC = Pane(name: "C")
        let pD = Pane(name: "D")
        let ws = Workspace(
            id: UUID(),
            name: "Grid",
            rootNode: SplitNode(
                direction: .vertical,
                first: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: pA),
                    second: SplitNode(pane: pB)
                ),
                second: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: pC),
                    second: SplitNode(pane: pD)
                )
            ),
            focusedPaneID: pA.id
        )

        ws.focusPaneInDirection(.right)
        #expect(ws.focusedPaneID == pB.id)

        ws.focusPane(id: pA.id)
        ws.focusPaneInDirection(.down)
        #expect(ws.focusedPaneID == pC.id)

        ws.focusPane(id: pD.id)
        ws.focusPaneInDirection(.left)
        #expect(ws.focusedPaneID == pC.id)

        ws.focusPane(id: pD.id)
        ws.focusPaneInDirection(.up)
        #expect(ws.focusedPaneID == pB.id)
    }

    @Test func directionalFocusMixedTree() {
        let pA = Pane(name: "A")
        let pB = Pane(name: "B")
        let pC = Pane(name: "C")
        let ws = Workspace(
            id: UUID(),
            name: "Mixed",
            rootNode: SplitNode(
                direction: .horizontal,
                first: SplitNode(pane: pA),
                second: SplitNode(
                    direction: .vertical,
                    first: SplitNode(pane: pB),
                    second: SplitNode(pane: pC)
                )
            ),
            focusedPaneID: pA.id
        )

        ws.focusPaneInDirection(.right)
        let focused = ws.focusedPaneID
        #expect(focused == pB.id || focused == pC.id)

        ws.focusPane(id: pB.id)
        ws.focusPaneInDirection(.left)
        #expect(ws.focusedPaneID == pA.id)
    }

    @Test func directionalFocusNonOverlappingPanesSkipped() {
        let pA = Pane(name: "A")
        let pB = Pane(name: "B")
        let pC = Pane(name: "C")
        let pD = Pane(name: "D")
        let ws = Workspace(
            id: UUID(),
            name: "Test",
            rootNode: SplitNode(
                direction: .vertical,
                first: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: pA),
                    second: SplitNode(pane: pB)
                ),
                second: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: pC),
                    second: SplitNode(pane: pD)
                )
            ),
            focusedPaneID: pB.id
        )

        ws.focusPaneInDirection(.down)
        #expect(ws.focusedPaneID == pD.id)
    }

    @Test func directionalFocusClearsAttention() {
        let pA = Pane(name: "A")
        let pB = Pane(name: "B")
        pB.attentionKind = .bell
        let ws = Workspace(
            id: UUID(),
            name: "Test",
            rootNode: SplitNode(
                direction: .horizontal,
                first: SplitNode(pane: pA),
                second: SplitNode(pane: pB)
            ),
            focusedPaneID: pA.id
        )
        ws.focusPaneInDirection(.right)
        #expect(ws.focusedPaneID == pB.id)
        #expect(pB.attentionKind == nil)
    }

    // MARK: - Sibling Splitting (i3-style)

    @Test func splitRightTwiceGivesThreeEqualPanes() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        let p3 = ws.splitFocusedPane(direction: .horizontal)!

        let rects = ws.rootNode.paneRects()
        #expect(rects.count == 3)
        #expect(abs(rects[p1.id]!.width - 1.0/3.0) < 0.001)
        #expect(abs(rects[p2.id]!.width - 1.0/3.0) < 0.001)
        #expect(abs(rects[p3.id]!.width - 1.0/3.0) < 0.001)
    }

    @Test func splitDownTwiceGivesThreeEqualPanes() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .vertical)!
        let p3 = ws.splitFocusedPane(direction: .vertical)!

        let rects = ws.rootNode.paneRects()
        #expect(rects.count == 3)
        #expect(abs(rects[p1.id]!.height - 1.0/3.0) < 0.001)
        #expect(abs(rects[p2.id]!.height - 1.0/3.0) < 0.001)
        #expect(abs(rects[p3.id]!.height - 1.0/3.0) < 0.001)
    }

    @Test func crossDirectionSplitDoesNotEqualizeParentChain() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!

        ws.focusPane(id: p2.id)
        _ = ws.splitFocusedPane(direction: .vertical)!

        let rects = ws.rootNode.paneRects()
        #expect(abs(rects[p1.id]!.width - 0.5) < 0.001)
    }

    // MARK: - Focus Next/Previous

    @Test func focusNextPaneWrapsAround() {
        let ws = Workspace(name: "Test")
        let firstPaneID = ws.focusedPaneID!
        _ = ws.splitFocusedPane(direction: .horizontal)
        let secondPaneID = ws.focusedPaneID!

        ws.focusNextPane()
        #expect(ws.focusedPaneID == firstPaneID)

        ws.focusNextPane()
        #expect(ws.focusedPaneID == secondPaneID)
    }

    @Test func focusPreviousPaneWrapsAround() {
        let ws = Workspace(name: "Test")
        let firstPaneID = ws.focusedPaneID!
        _ = ws.splitFocusedPane(direction: .horizontal)

        ws.focusPane(id: firstPaneID)
        ws.focusPreviousPane()
        #expect(ws.focusedPaneID != firstPaneID)
    }

    @Test func focusNextPaneNoOpWithSinglePane() {
        let ws = Workspace(name: "Test")
        let onlyPaneID = ws.focusedPaneID!

        ws.focusNextPane()
        #expect(ws.focusedPaneID == onlyPaneID)
    }

    @Test func focusPreviousPaneNoOpWithSinglePane() {
        let ws = Workspace(name: "Test")
        let onlyPaneID = ws.focusedPaneID!

        ws.focusPreviousPane()
        #expect(ws.focusedPaneID == onlyPaneID)
    }

    // MARK: - Codable

    @Test func roundTrip() throws {
        let ws = Workspace(name: "Project")
        ws.repoPath = "/Users/test/project"
        ws.splitFocusedPane(direction: .horizontal)
        ws.allPanes[0].branch = "main"

        let data = try JSONEncoder().encode(ws)
        let restored = try JSONDecoder().decode(Workspace.self, from: data)

        #expect(restored.id == ws.id)
        #expect(restored.name == "Project")
        #expect(restored.repoPath == "/Users/test/project")
        #expect(restored.allPanes.count == 2)
        #expect(restored.focusedPaneID == ws.focusedPaneID)
        #expect(restored.allPanes[0].branch == "main")
    }

}
