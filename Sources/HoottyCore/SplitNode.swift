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
        case leaf(PaneGroup)
        case split(direction: SplitDirection, first: SplitNode, second: SplitNode)
    }

    public init(id: UUID = UUID(), paneGroup: PaneGroup) {
        self.id = id
        self.content = .leaf(paneGroup)
    }

    public init(id: UUID = UUID(), direction: SplitDirection, first: SplitNode, second: SplitNode, ratio: Double = 0.5) {
        self.id = id
        self.content = .split(direction: direction, first: first, second: second)
        self.splitRatio = ratio
    }

    public func allPanes() -> [Pane] {
        switch content {
        case .leaf(let group):
            return group.panes
        case .split(_, let first, let second):
            return first.allPanes() + second.allPanes()
        }
    }

    public func allPaneGroups() -> [PaneGroup] {
        switch content {
        case .leaf(let group):
            return [group]
        case .split(_, let first, let second):
            return first.allPaneGroups() + second.allPaneGroups()
        }
    }

    public func findPaneGroup(containingPaneID paneID: UUID) -> PaneGroup? {
        switch content {
        case .leaf(let group):
            return group.panes.contains(where: { $0.id == paneID }) ? group : nil
        case .split(_, let first, let second):
            return first.findPaneGroup(containingPaneID: paneID) ?? second.findPaneGroup(containingPaneID: paneID)
        }
    }

    @discardableResult
    public func splitGroup(groupID: UUID, direction: SplitDirection, newGroup: PaneGroup, placeBefore: Bool = false) -> Bool {
        switch content {
        case .leaf(let group) where group.id == groupID:
            let oldNode = SplitNode(paneGroup: group)
            let newNode = SplitNode(paneGroup: newGroup)
            if placeBefore {
                self.content = .split(direction: direction, first: newNode, second: oldNode)
            } else {
                self.content = .split(direction: direction, first: oldNode, second: newNode)
            }
            return true
        case .split(_, let first, let second):
            return first.splitGroup(groupID: groupID, direction: direction, newGroup: newGroup, placeBefore: placeBefore)
                || second.splitGroup(groupID: groupID, direction: direction, newGroup: newGroup, placeBefore: placeBefore)
        default:
            return false
        }
    }

    @discardableResult
    public func removePaneGroup(id: UUID) -> Bool {
        switch content {
        case .leaf:
            return false
        case .split(_, let first, let second):
            if case .leaf(let group) = first.content, group.id == id {
                self.content = second.content
                self.splitRatio = second.splitRatio
                return true
            }
            if case .leaf(let group) = second.content, group.id == id {
                self.content = first.content
                self.splitRatio = first.splitRatio
                return true
            }
            return first.removePaneGroup(id: id) || second.removePaneGroup(id: id)
        }
    }
}

extension SplitNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, paneGroup, direction, first, second, splitRatio
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
            let paneGroup = try container.decode(PaneGroup.self, forKey: .paneGroup)
            self.init(id: id, paneGroup: paneGroup)
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
        case .leaf(let group):
            try container.encode(NodeType.leaf, forKey: .type)
            try container.encode(group, forKey: .paneGroup)
        case .split(let direction, let first, let second):
            try container.encode(NodeType.split, forKey: .type)
            try container.encode(direction, forKey: .direction)
            try container.encode(first, forKey: .first)
            try container.encode(second, forKey: .second)
            try container.encode(splitRatio, forKey: .splitRatio)
        }
    }
}
