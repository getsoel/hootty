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
}
