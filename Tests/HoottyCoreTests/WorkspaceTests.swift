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

    // MARK: - Directional Focus

    @Test func directionalFocusHorizontalSplit() {
        let ws = Workspace(name: "Test")
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        // After split right: P1 | P2, focus on P2
        ws.focusPane(id: p1.id)

        // Focus right from P1 → P2
        ws.focusPaneInDirection(.right)
        #expect(ws.focusedPaneID == p2.id)

        // Focus left from P2 → P1
        ws.focusPaneInDirection(.left)
        #expect(ws.focusedPaneID == p1.id)

        // Up/down are no-ops
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

        // Focus down from P1 → P2
        ws.focusPaneInDirection(.down)
        #expect(ws.focusedPaneID == p2.id)

        // Focus up from P2 → P1
        ws.focusPaneInDirection(.up)
        #expect(ws.focusedPaneID == p1.id)

        // Left/right are no-ops
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
        // Build V(H(A,B), H(C,D))
        let ws = Workspace(name: "Test")
        let a = ws.allPanes[0]
        ws.focusPane(id: a.id)
        _ = ws.splitFocusedPane(direction: .horizontal)! // A | B
        ws.focusPane(id: a.id)
        _ = ws.splitFocusedPane(direction: .vertical)!   // A/C on left side
        // Now: V(H(A, B), C) — but we need V(H(A,B), H(C,D))
        // Actually the split happens on the focused leaf, so let me build it differently.
        // Start fresh: build manually using SplitNode
        let pA = Pane(name: "A")
        let pB = Pane(name: "B")
        let pC = Pane(name: "C")
        let pD = Pane(name: "D")
        let ws2 = Workspace(
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

        // From A: right → B, down → C
        ws2.focusPaneInDirection(.right)
        #expect(ws2.focusedPaneID == pB.id)

        ws2.focusPane(id: pA.id)
        ws2.focusPaneInDirection(.down)
        #expect(ws2.focusedPaneID == pC.id)

        // From D: left → C, up → B
        ws2.focusPane(id: pD.id)
        ws2.focusPaneInDirection(.left)
        #expect(ws2.focusedPaneID == pC.id)

        ws2.focusPane(id: pD.id)
        ws2.focusPaneInDirection(.up)
        #expect(ws2.focusedPaneID == pB.id)
    }

    @Test func directionalFocusMixedTree() {
        // H(A, V(B, C))
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

        // From A: right → B (overlaps top half) or C (overlaps bottom half)
        // Both overlap, closer center wins
        ws.focusPaneInDirection(.right)
        // A spans full height, B is top half, C is bottom half
        // B.midY = 0.25, C.midY = 0.75, A.midY = 0.5
        // B perpDist = 0.25, C perpDist = 0.25 — tie, both adjacent at same primary dist
        // With tie on perpDist, either is valid; B wins because it's iterated first or same dist
        let focused = ws.focusedPaneID
        #expect(focused == pB.id || focused == pC.id)

        // From B: left → A
        ws.focusPane(id: pB.id)
        ws.focusPaneInDirection(.left)
        #expect(ws.focusedPaneID == pA.id)
    }

    @Test func directionalFocusNonOverlappingPanesSkipped() {
        // V(H(A, B), C) where C is full width
        // Focus A, go right → B (overlapping). Focus A, go down → C (overlapping).
        // But B and C don't overlap horizontally... actually C is full width so they do.
        // Let's test: V(H(A, B), H(C, D)) focus A, go down → C (same x range)
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

        // From B (right half, top row): down → D (right half, bottom row)
        // C (left half, bottom row) doesn't overlap B's x range
        ws.focusPaneInDirection(.down)
        #expect(ws.focusedPaneID == pD.id)
    }

    @Test func directionalFocusClearsAttention() {
        let pA = Pane(name: "A")
        let pB = Pane(name: "B")
        pB.attentionKind = .input
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

        // Now split p2 vertically — this should NOT equalize the horizontal parent
        ws.focusPane(id: p2.id)
        _ = ws.splitFocusedPane(direction: .vertical)!

        let rects = ws.rootNode.paneRects()
        // p1 should still have ~0.5 width (equalized from 2-pane horizontal split)
        #expect(abs(rects[p1.id]!.width - 0.5) < 0.001)
    }
}
