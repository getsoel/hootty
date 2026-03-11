import Testing
import Foundation
@testable import HoottyCore

@Suite struct SplitNodeTests {
    @Test func splitUnknownPaneReturnsFalse() {
        let pane = Pane(name: "Test")
        let node = SplitNode(pane: pane)
        let result = node.splitPane(paneID: UUID(), direction: .horizontal, newPane: Pane(name: "New"))
        #expect(result == false)
        #expect(node.allPanes().count == 1)
    }

    @Test func removePaneNoOpOnLeaf() {
        let pane = Pane(name: "Test")
        let node = SplitNode(pane: pane)
        let result = node.removePane(id: pane.id)
        #expect(result == false)
        #expect(node.allPanes().count == 1)
    }

    // MARK: - paneRects

    @Test func paneRectsHorizontalSplit() {
        let pane1 = Pane(name: "P1")
        let pane2 = Pane(name: "P2")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: pane1),
            second: SplitNode(pane: pane2),
            ratio: 0.5
        )
        let rects = node.paneRects()
        #expect(rects.count == 2)
        let r1 = rects[pane1.id]!
        let r2 = rects[pane2.id]!
        #expect(abs(r1.minX) < 0.001)
        #expect(abs(r1.width - 0.5) < 0.001)
        #expect(abs(r1.height - 1.0) < 0.001)
        #expect(abs(r2.minX - 0.5) < 0.001)
        #expect(abs(r2.width - 0.5) < 0.001)
        #expect(abs(r2.height - 1.0) < 0.001)
    }

    @Test func paneRectsVerticalSplit() {
        let pane1 = Pane(name: "P1")
        let pane2 = Pane(name: "P2")
        let node = SplitNode(
            direction: .vertical,
            first: SplitNode(pane: pane1),
            second: SplitNode(pane: pane2),
            ratio: 0.5
        )
        let rects = node.paneRects()
        #expect(rects.count == 2)
        let r1 = rects[pane1.id]!
        let r2 = rects[pane2.id]!
        #expect(abs(r1.minY) < 0.001)
        #expect(abs(r1.height - 0.5) < 0.001)
        #expect(abs(r1.width - 1.0) < 0.001)
        #expect(abs(r2.minY - 0.5) < 0.001)
        #expect(abs(r2.height - 0.5) < 0.001)
        #expect(abs(r2.width - 1.0) < 0.001)
    }

    @Test func paneRectsCustomRatio() {
        let pane1 = Pane(name: "P1")
        let pane2 = Pane(name: "P2")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: pane1),
            second: SplitNode(pane: pane2),
            ratio: 0.3
        )
        let rects = node.paneRects()
        let r1 = rects[pane1.id]!
        let r2 = rects[pane2.id]!
        #expect(abs(r1.width - 0.3) < 0.001)
        #expect(abs(r2.minX - 0.3) < 0.001)
        #expect(abs(r2.width - 0.7) < 0.001)
    }

    // MARK: - swapPanes

    @Test func swapPanesSimpleSplit() {
        let pane1 = Pane(name: "P1")
        let pane2 = Pane(name: "P2")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: pane1),
            second: SplitNode(pane: pane2)
        )
        let result = node.swapPanes(pane1.id, pane2.id)
        #expect(result == true)
        let panes = node.allPanes()
        #expect(panes[0].id == pane2.id)
        #expect(panes[1].id == pane1.id)
    }

    @Test func swapPanesSameID() {
        let pane = Pane(name: "P1")
        let node = SplitNode(pane: pane)
        let result = node.swapPanes(pane.id, pane.id)
        #expect(result == false)
    }

    @Test func swapPanesUnknownID() {
        let pane1 = Pane(name: "P1")
        let pane2 = Pane(name: "P2")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: pane1),
            second: SplitNode(pane: pane2)
        )
        let result = node.swapPanes(pane1.id, UUID())
        #expect(result == false)
        // Verify nothing changed
        let panes = node.allPanes()
        #expect(panes[0].id == pane1.id)
        #expect(panes[1].id == pane2.id)
    }

    // MARK: - Equalize Splits

    @Test func equalizeOnLeafIsNoOp() {
        let node = SplitNode(pane: Pane(name: "P1"))
        node.equalizeSplits()
        // Should not crash; still a leaf
        #expect(node.allPanes().count == 1)
    }

    @Test func equalizeSetsAllRatiosToHalf() {
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        // H(P1, V(P2, P3)) with skewed ratios
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(
                direction: .vertical,
                first: SplitNode(pane: p2),
                second: SplitNode(pane: p3),
                ratio: 0.7
            ),
            ratio: 0.3
        )
        node.equalizeSplits()
        #expect(abs(node.splitRatio - 0.5) < 0.001)
        if case .split(_, _, let second) = node.content {
            #expect(abs(second.splitRatio - 0.5) < 0.001)
        }
    }

    @Test func equalizeDeepTreePreservesFullRectCoverage() {
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        let p4 = Pane(name: "P4")
        // H(V(P1, P2), V(P3, P4)) with various ratios
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(
                direction: .vertical,
                first: SplitNode(pane: p1),
                second: SplitNode(pane: p2),
                ratio: 0.2
            ),
            second: SplitNode(
                direction: .vertical,
                first: SplitNode(pane: p3),
                second: SplitNode(pane: p4),
                ratio: 0.8
            ),
            ratio: 0.1
        )
        node.equalizeSplits()
        let rects = node.paneRects()
        #expect(rects.count == 4)
        let totalArea = rects.values.reduce(0.0) { $0 + $1.width * $1.height }
        #expect(abs(totalArea - 1.0) < 0.001)
        // All 4 panes should be equal area (0.25 each)
        for (_, rect) in rects {
            #expect(abs(rect.width * rect.height - 0.25) < 0.001)
        }
    }

    // MARK: - Same-Direction Chain

    @Test func sameDirectionChainLeafCountSimple() {
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(pane: p2)
        )
        #expect(node.sameDirectionChainLeafCount(direction: .horizontal) == 2)
        #expect(node.sameDirectionChainLeafCount(direction: .vertical) == 1)
    }

    @Test func sameDirectionChainLeafCountDeep() {
        // H(P1, H(P2, H(P3, P4))) — right-leaning chain of 4
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        let p4 = Pane(name: "P4")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(
                direction: .horizontal,
                first: SplitNode(pane: p2),
                second: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: p3),
                    second: SplitNode(pane: p4)
                )
            )
        )
        #expect(node.sameDirectionChainLeafCount(direction: .horizontal) == 4)
    }

    @Test func sameDirectionChainLeafCountMixed() {
        // H(P1, V(P2, P3)) — cross-direction subtree counts as 1 terminal
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(
                direction: .vertical,
                first: SplitNode(pane: p2),
                second: SplitNode(pane: p3)
            )
        )
        #expect(node.sameDirectionChainLeafCount(direction: .horizontal) == 2)
    }

    @Test func equalizeSameDirectionChainThreeLeaves() {
        // H(P1, H(P2, P3)) — equalize should give each 1/3
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(
                direction: .horizontal,
                first: SplitNode(pane: p2),
                second: SplitNode(pane: p3)
            )
        )
        node.equalizeSameDirectionChain(direction: .horizontal)
        let rects = node.paneRects()
        #expect(abs(rects[p1.id]!.width - 1.0/3.0) < 0.001)
        #expect(abs(rects[p2.id]!.width - 1.0/3.0) < 0.001)
        #expect(abs(rects[p3.id]!.width - 1.0/3.0) < 0.001)
    }

    @Test func equalizeSameDirectionChainFourLeaves() {
        // H(P1, H(P2, H(P3, P4))) — equalize should give each 1/4
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        let p4 = Pane(name: "P4")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(
                direction: .horizontal,
                first: SplitNode(pane: p2),
                second: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: p3),
                    second: SplitNode(pane: p4)
                )
            )
        )
        node.equalizeSameDirectionChain(direction: .horizontal)
        let rects = node.paneRects()
        for pane in [p1, p2, p3, p4] {
            #expect(abs(rects[pane.id]!.width - 0.25) < 0.001)
        }
    }

    // MARK: - swapPanes

    @Test func swapPanesDeepTree() {
        // Build: H(P1, V(P2, H(P3, P4)))
        let p1 = Pane(name: "P1")
        let p2 = Pane(name: "P2")
        let p3 = Pane(name: "P3")
        let p4 = Pane(name: "P4")
        let node = SplitNode(
            direction: .horizontal,
            first: SplitNode(pane: p1),
            second: SplitNode(
                direction: .vertical,
                first: SplitNode(pane: p2),
                second: SplitNode(
                    direction: .horizontal,
                    first: SplitNode(pane: p3),
                    second: SplitNode(pane: p4)
                )
            )
        )

        // Swap p1 (top-level left) with p4 (deepest right)
        let result = node.swapPanes(p1.id, p4.id)
        #expect(result == true)
        let panes = node.allPanes()
        #expect(panes[0].id == p4.id)
        #expect(panes[1].id == p2.id)
        #expect(panes[2].id == p3.id)
        #expect(panes[3].id == p1.id)
    }
}
