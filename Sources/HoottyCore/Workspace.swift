import Foundation

@Observable
public final class Workspace: Identifiable {
    public let id: UUID
    public var name: String
    public var rootNode: SplitNode
    public var focusedPaneGroupID: UUID?
    private var groupCounter = 0

    public var allPaneGroups: [PaneGroup] {
        rootNode.allPaneGroups()
    }

    public var allPanes: [Pane] {
        rootNode.allPanes()
    }

    public var focusedPaneGroup: PaneGroup? {
        let groups = allPaneGroups
        guard let focusedPaneGroupID else { return groups.first }
        return groups.first { $0.id == focusedPaneGroupID } ?? groups.first
    }

    public var isRunning: Bool {
        allPanes.contains { $0.isRunning }
    }

    public var hasAttentionGroup: Bool {
        let groups = allPaneGroups
        for group in groups where group.id != focusedPaneGroupID {
            if group.needsAttention { return true }
        }
        if let focused = groups.first(where: { $0.id == focusedPaneGroupID }) {
            for pane in focused.panes where pane.id != focused.selectedPaneID {
                if pane.needsAttention { return true }
            }
        }
        return false
    }

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.groupCounter = 1
        let group = PaneGroup(name: "Group 1")
        self.rootNode = SplitNode(paneGroup: group)
        self.focusedPaneGroupID = group.id
    }

    /// Restoration initializer for decoding persisted state.
    public init(id: UUID, name: String, rootNode: SplitNode, focusedPaneGroupID: UUID?) {
        self.id = id
        self.name = name
        self.rootNode = rootNode
        self.focusedPaneGroupID = focusedPaneGroupID
        self.groupCounter = rootNode.allPaneGroups().count
    }

    @discardableResult
    public func addPaneToFocusedGroup(shell: String = "/bin/zsh", workingDirectory: String? = nil) -> Pane? {
        guard let group = focusedPaneGroup else { return nil }
        return group.addPane(shell: shell, workingDirectory: workingDirectory)
    }

    @discardableResult
    public func splitFocusedGroup(direction: SplitDirection) -> PaneGroup? {
        guard let group = focusedPaneGroup else { return nil }
        groupCounter += 1
        let selectedPane = group.selectedPane
        let newGroup = PaneGroup(
            name: "Group \(groupCounter)",
            shell: selectedPane?.shell ?? "/bin/zsh",
            workingDirectory: selectedPane?.workingDirectory
        )
        if rootNode.splitGroup(groupID: group.id, direction: direction, newGroup: newGroup) {
            focusedPaneGroupID = newGroup.id
            return newGroup
        }
        return nil
    }

    public func removePaneGroup(id: UUID) {
        let groups = allPaneGroups
        guard groups.count > 1 else {
            // Last group — replace with fresh one
            groupCounter += 1
            let newGroup = PaneGroup(name: "Group \(groupCounter)")
            rootNode.content = .leaf(newGroup)
            focusedPaneGroupID = newGroup.id
            return
        }
        if rootNode.removePaneGroup(id: id) {
            if focusedPaneGroupID == id {
                focusedPaneGroupID = allPaneGroups.first?.id
            }
        }
    }

    public func closePane(id paneID: UUID) {
        guard let (group, _) = findPane(id: paneID) else { return }
        if group.panes.count > 1 {
            group.removePane(id: paneID)
        } else {
            removePaneGroup(id: group.id)
        }
    }

    public func focusPaneGroup(id: UUID) {
        guard let group = rootNode.allPaneGroups().first(where: { $0.id == id }) else { return }
        focusedPaneGroupID = id
        group.selectedPane?.needsAttention = false
    }

    public func focusPane(id: UUID) {
        guard let group = rootNode.findPaneGroup(containingPaneID: id) else { return }
        focusedPaneGroupID = group.id
        group.selectPane(id: id)
    }

    public func findPane(id: UUID) -> (PaneGroup, Pane)? {
        for group in allPaneGroups {
            if let pane = group.panes.first(where: { $0.id == id }) {
                return (group, pane)
            }
        }
        return nil
    }
}

extension Workspace: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, rootNode, focusedPaneGroupID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            rootNode: try container.decode(SplitNode.self, forKey: .rootNode),
            focusedPaneGroupID: try container.decodeIfPresent(UUID.self, forKey: .focusedPaneGroupID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rootNode, forKey: .rootNode)
        try container.encode(focusedPaneGroupID, forKey: .focusedPaneGroupID)
    }
}
