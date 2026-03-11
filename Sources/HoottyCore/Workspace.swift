import Foundation

public enum FocusDirection: String, CaseIterable, Sendable {
    case up, down, left, right
}

@Observable
public final class Workspace: Identifiable {
    public let id: UUID
    public var name: String
    public var rootNode: SplitNode
    public var focusedPaneID: UUID?
    private var paneCounter = 0

    public var allPanes: [Pane] {
        rootNode.allPanes()
    }

    public var focusedPane: Pane? {
        guard let focusedPaneID else { return rootNode.firstPane() }
        return rootNode.findPane(id: focusedPaneID) ?? rootNode.firstPane()
    }

    public var isRunning: Bool {
        allPanes.contains { $0.isRunning }
    }

    public var hasThinkingPane: Bool {
        allPanes.contains { $0.isThinking }
    }

    public var hasAttention: Bool {
        attentionKind != nil
    }

    /// Returns the most urgent attention kind across unfocused panes (input > idle > bell).
    public var attentionKind: AttentionKind? {
        var result: AttentionKind?
        for pane in allPanes where pane.id != focusedPaneID {
            if let kind = pane.attentionKind {
                if kind == .input { return .input }
                if kind == .idle {
                    result = .idle
                } else if result == nil {
                    result = kind
                }
            }
        }
        return result
    }

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.paneCounter = 1
        let pane = Pane(name: "Pane 1")
        self.rootNode = SplitNode(pane: pane)
        self.focusedPaneID = pane.id
    }

    /// Restoration initializer for decoding persisted state.
    public init(id: UUID, name: String, rootNode: SplitNode, focusedPaneID: UUID?) {
        self.id = id
        self.name = name
        self.rootNode = rootNode
        self.focusedPaneID = focusedPaneID
        self.paneCounter = rootNode.allPanes().count
    }

    @discardableResult
    public func splitFocusedPane(direction: SplitDirection, placeBefore: Bool = false) -> Pane? {
        guard let focused = focusedPane else { return nil }
        paneCounter += 1
        let newPane = Pane(
            name: "Pane \(paneCounter)",
            shell: focused.shell,
            workingDirectory: focused.workingDirectory
        )
        if rootNode.splitPane(paneID: focused.id, direction: direction, newPane: newPane, placeBefore: placeBefore) {
            focusedPaneID = newPane.id
            equalizeChainContaining(paneID: newPane.id, direction: direction)
            return newPane
        }
        return nil
    }

    // MARK: - Equalize

    public func equalizeSplits() {
        rootNode.equalizeSplits()
    }

    // MARK: - Directional Focus

    public func focusPaneInDirection(_ direction: FocusDirection) {
        guard let currentID = focusedPaneID else { return }
        let rects = rootNode.paneRects()
        guard let focusedRect = rects[currentID] else { return }

        let epsilon = 0.001
        var bestID: UUID?
        var bestPrimary = Double.infinity
        var bestPerp = Double.infinity

        for (candidateID, candidateRect) in rects where candidateID != currentID {
            let adj = adjacency(from: focusedRect, to: candidateRect, direction: direction, epsilon: epsilon)
            guard adj.isAdjacent && adj.hasOverlap else { continue }
            if adj.primaryDist < bestPrimary - epsilon
                || (abs(adj.primaryDist - bestPrimary) < epsilon && adj.perpendicularDist < bestPerp) {
                bestPrimary = adj.primaryDist
                bestPerp = adj.perpendicularDist
                bestID = candidateID
            }
        }

        if let bestID {
            focusPane(id: bestID)
        }
    }

    private func adjacency(
        from src: CGRect, to dst: CGRect, direction: FocusDirection, epsilon: Double
    ) -> (isAdjacent: Bool, primaryDist: Double, hasOverlap: Bool, perpendicularDist: Double) {
        let isAdj: Bool
        let primaryDist: Double
        let hasOverlap: Bool
        let perpDist: Double

        switch direction {
        case .right:
            isAdj = dst.minX >= src.maxX - epsilon
            primaryDist = dst.minX - src.maxX
            hasOverlap = dst.maxY > src.minY + epsilon && dst.minY < src.maxY - epsilon
            perpDist = abs(dst.midY - src.midY)
        case .left:
            isAdj = dst.maxX <= src.minX + epsilon
            primaryDist = src.minX - dst.maxX
            hasOverlap = dst.maxY > src.minY + epsilon && dst.minY < src.maxY - epsilon
            perpDist = abs(dst.midY - src.midY)
        case .down:
            isAdj = dst.minY >= src.maxY - epsilon
            primaryDist = dst.minY - src.maxY
            hasOverlap = dst.maxX > src.minX + epsilon && dst.minX < src.maxX - epsilon
            perpDist = abs(dst.midX - src.midX)
        case .up:
            isAdj = dst.maxY <= src.minY + epsilon
            primaryDist = src.minY - dst.maxY
            hasOverlap = dst.maxX > src.minX + epsilon && dst.minX < src.maxX - epsilon
            perpDist = abs(dst.midX - src.midX)
        }

        return (isAdj, primaryDist, hasOverlap, perpDist)
    }

    // MARK: - Chain Equalization (i3-style)

    private func equalizeChainContaining(paneID: UUID, direction: SplitDirection) {
        let chain = rootNode.ancestorChain(for: paneID)
        // Walk from the pane's parent upward to find the highest contiguous same-direction ancestor
        var highestSameDir: SplitNode?
        for entry in chain.reversed() {
            if case .split(let dir, _, _) = entry.node.content, dir == direction {
                highestSameDir = entry.node
            } else {
                break
            }
        }
        highestSameDir?.equalizeSameDirectionChain(direction: direction)
    }

    public func removePane(id: UUID) {
        if !rootNode.removePane(id: id) {
            // Last pane (removePane returns false on leaf) — replace with fresh one
            paneCounter += 1
            let newPane = Pane(name: "Pane \(paneCounter)")
            rootNode.content = .leaf(newPane)
            focusedPaneID = newPane.id
            return
        }
        if focusedPaneID == id {
            focusedPaneID = rootNode.firstPane()?.id
        }
    }

    public func focusPane(id: UUID) {
        guard let pane = rootNode.findPane(id: id) else { return }
        focusedPaneID = id
        pane.attentionKind = nil
    }

    public func findPane(id: UUID) -> Pane? {
        rootNode.findPane(id: id)
    }

    @discardableResult
    public func swapPanes(_ id1: UUID, _ id2: UUID) -> Bool {
        rootNode.swapPanes(id1, id2)
    }

    public func focusNextPane() {
        let panes = allPanes
        guard panes.count > 1,
              let currentID = focusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIdx = (idx + 1) % panes.count
        focusPane(id: panes[nextIdx].id)
    }

    public func focusPreviousPane() {
        let panes = allPanes
        guard panes.count > 1,
              let currentID = focusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == currentID }) else { return }
        let prevIdx = (idx - 1 + panes.count) % panes.count
        focusPane(id: panes[prevIdx].id)
    }
}

extension Workspace: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, rootNode, focusedPaneID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            rootNode: try container.decode(SplitNode.self, forKey: .rootNode),
            focusedPaneID: try container.decodeIfPresent(UUID.self, forKey: .focusedPaneID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rootNode, forKey: .rootNode)
        try container.encode(focusedPaneID, forKey: .focusedPaneID)
    }
}
