import Foundation

public enum SplitDirection: String, Codable {
    case horizontal
    case vertical
}

@Observable
public final class SplitNode: Identifiable {
    public let id: UUID
    public var content: SplitContent
    public var splitRatio: Double = 0.5

    public enum SplitContent {
        case leaf(Pane)
        case split(direction: SplitDirection, first: SplitNode, second: SplitNode)
    }

    public init(id: UUID = UUID(), pane: Pane) {
        self.id = id
        self.content = .leaf(pane)
    }

    public init(id: UUID = UUID(), direction: SplitDirection, first: SplitNode, second: SplitNode, ratio: Double = 0.5) {
        self.id = id
        self.content = .split(direction: direction, first: first, second: second)
        self.splitRatio = ratio
    }

    public func allPanes() -> [Pane] {
        var result: [Pane] = []
        collectPanes(into: &result)
        return result
    }

    private func collectPanes(into result: inout [Pane]) {
        switch content {
        case .leaf(let pane):
            result.append(pane)
        case .split(_, let first, let second):
            first.collectPanes(into: &result)
            second.collectPanes(into: &result)
        }
    }

    public func paneRects() -> [UUID: CGRect] {
        var result: [UUID: CGRect] = [:]
        collectRects(into: &result, rect: CGRect(x: 0, y: 0, width: 1, height: 1))
        return result
    }

    private func collectRects(into result: inout [UUID: CGRect], rect: CGRect) {
        switch content {
        case .leaf(let pane):
            result[pane.id] = rect
        case .split(let direction, let first, let second):
            switch direction {
            case .horizontal:
                let w = rect.width * splitRatio
                first.collectRects(into: &result, rect: CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height))
                second.collectRects(into: &result, rect: CGRect(x: rect.minX + w, y: rect.minY, width: rect.width - w, height: rect.height))
            case .vertical:
                let h = rect.height * splitRatio
                first.collectRects(into: &result, rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h))
                second.collectRects(into: &result, rect: CGRect(x: rect.minX, y: rect.minY + h, width: rect.width, height: rect.height - h))
            }
        }
    }

    public func firstPane() -> Pane? {
        switch content {
        case .leaf(let pane):
            return pane
        case .split(_, let first, _):
            return first.firstPane()
        }
    }

    public func findPane(id: UUID) -> Pane? {
        switch content {
        case .leaf(let pane):
            return pane.id == id ? pane : nil
        case .split(_, let first, let second):
            return first.findPane(id: id) ?? second.findPane(id: id)
        }
    }

    public func findLeafNode(paneID: UUID) -> SplitNode? {
        switch content {
        case .leaf(let pane):
            return pane.id == paneID ? self : nil
        case .split(_, let first, let second):
            return first.findLeafNode(paneID: paneID) ?? second.findLeafNode(paneID: paneID)
        }
    }

    @discardableResult
    public func swapPanes(_ id1: UUID, _ id2: UUID) -> Bool {
        guard id1 != id2 else { return false }
        guard let node1 = findLeafNode(paneID: id1),
              let node2 = findLeafNode(paneID: id2) else { return false }
        let temp = node1.content
        node1.content = node2.content
        node2.content = temp
        return true
    }

    @discardableResult
    public func splitPane(paneID: UUID, direction: SplitDirection, newPane: Pane, placeBefore: Bool = false) -> Bool {
        switch content {
        case .leaf(let pane) where pane.id == paneID:
            let oldNode = SplitNode(pane: pane)
            let newNode = SplitNode(pane: newPane)
            if placeBefore {
                self.content = .split(direction: direction, first: newNode, second: oldNode)
            } else {
                self.content = .split(direction: direction, first: oldNode, second: newNode)
            }
            return true
        case .split(_, let first, let second):
            return first.splitPane(paneID: paneID, direction: direction, newPane: newPane, placeBefore: placeBefore)
                || second.splitPane(paneID: paneID, direction: direction, newPane: newPane, placeBefore: placeBefore)
        default:
            return false
        }
    }

    // MARK: - Equalize

    /// Reset all split ratios in this subtree to 0.5 (equal division at each level).
    public func equalizeSplits() {
        guard case .split(_, let first, let second) = content else { return }
        splitRatio = 0.5
        first.equalizeSplits()
        second.equalizeSplits()
    }

    // MARK: - Same-Direction Chain (i3-style sibling splitting)

    /// Count terminals (leaves or cross-direction subtrees) reachable through
    /// same-direction splits from this node.
    public func sameDirectionChainLeafCount(direction: SplitDirection) -> Int {
        guard case .split(let dir, let first, let second) = content, dir == direction else {
            return 1
        }
        return first.sameDirectionChainLeafCount(direction: direction)
             + second.sameDirectionChainLeafCount(direction: direction)
    }

    /// Equalize ratios so each terminal in a same-direction chain gets equal space.
    /// At each node in the chain: splitRatio = firstChildTerminalCount / totalCount.
    public func equalizeSameDirectionChain(direction: SplitDirection) {
        guard case .split(let dir, let first, let second) = content, dir == direction else { return }
        let total = sameDirectionChainLeafCount(direction: direction)
        let firstCount = first.sameDirectionChainLeafCount(direction: direction)
        splitRatio = Double(firstCount) / Double(total)
        first.equalizeSameDirectionChain(direction: direction)
        second.equalizeSameDirectionChain(direction: direction)
    }

    /// Return the ancestor path from this node to the parent of the given paneID.
    /// Each entry: (splitNode, paneIsInFirstChild: Bool).
    public func ancestorChain(for paneID: UUID) -> [(node: SplitNode, childIsFirst: Bool)] {
        switch content {
        case .leaf(let pane):
            return pane.id == paneID ? [] : []
        case .split(_, let first, let second):
            if first.containsPane(id: paneID) {
                return [(node: self, childIsFirst: true)] + first.ancestorChain(for: paneID)
            } else if second.containsPane(id: paneID) {
                return [(node: self, childIsFirst: false)] + second.ancestorChain(for: paneID)
            }
            return []
        }
    }

    /// Whether this subtree contains a pane with the given ID.
    public func containsPane(id: UUID) -> Bool {
        findPane(id: id) != nil
    }

    @discardableResult
    public func removePane(id: UUID) -> Bool {
        switch content {
        case .leaf:
            return false
        case .split(_, let first, let second):
            if case .leaf(let pane) = first.content, pane.id == id {
                self.content = second.content
                self.splitRatio = second.splitRatio
                return true
            }
            if case .leaf(let pane) = second.content, pane.id == id {
                self.content = first.content
                self.splitRatio = first.splitRatio
                return true
            }
            return first.removePane(id: id) || second.removePane(id: id)
        }
    }
}

extension SplitNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, pane, direction, first, second, splitRatio
    }

    private enum NodeType: String, Codable {
        case leaf, split
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let type = try container.decode(NodeType.self, forKey: .type)

        switch type {
        case .leaf:
            let pane = try container.decode(Pane.self, forKey: .pane)
            self.init(id: id, pane: pane)
        case .split:
            let direction = try container.decode(SplitDirection.self, forKey: .direction)
            let first = try container.decode(SplitNode.self, forKey: .first)
            let second = try container.decode(SplitNode.self, forKey: .second)
            let ratio = try container.decode(Double.self, forKey: .splitRatio)
            self.init(id: id, direction: direction, first: first, second: second, ratio: ratio)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)

        switch content {
        case .leaf(let pane):
            try container.encode(NodeType.leaf, forKey: .type)
            try container.encode(pane, forKey: .pane)
        case .split(let direction, let first, let second):
            try container.encode(NodeType.split, forKey: .type)
            try container.encode(direction, forKey: .direction)
            try container.encode(first, forKey: .first)
            try container.encode(second, forKey: .second)
            try container.encode(splitRatio, forKey: .splitRatio)
        }
    }
}
