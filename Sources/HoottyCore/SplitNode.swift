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
