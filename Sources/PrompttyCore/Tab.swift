import Foundation

@Observable
public final class Tab: Identifiable {
    public let id: UUID
    public var name: String
    public var rootNode: SplitNode
    public var focusedPaneID: UUID?
    private var paneCounter = 0

    public var isRunning: Bool {
        allPanes.contains { $0.isRunning }
    }

    public var needsAttention: Bool {
        allPanes.contains { $0.needsAttention }
    }

    public var allPanes: [Pane] {
        rootNode.allPanes()
    }

    public var focusedPane: Pane? {
        guard let focusedPaneID else { return allPanes.first }
        return allPanes.first { $0.id == focusedPaneID } ?? allPanes.first
    }

    // Convenience accessors for the primary pane (backwards compat)
    public var shell: String {
        get { focusedPane?.shell ?? "/bin/zsh" }
        set { focusedPane?.shell = newValue }
    }

    public var workingDirectory: String {
        get { focusedPane?.workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path }
        set { focusedPane?.workingDirectory = newValue }
    }

    public init(name: String, shell: String = "/bin/zsh", workingDirectory: String? = nil) {
        self.id = UUID()
        self.name = name
        let pane = Pane(name: name, shell: shell, workingDirectory: workingDirectory)
        self.rootNode = SplitNode(pane: pane)
        self.focusedPaneID = pane.id
        self.paneCounter = 1
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
    public func splitPane(paneID: UUID, direction: SplitDirection) -> Pane? {
        paneCounter += 1
        let targetPane = allPanes.first { $0.id == paneID }
        let newPane = Pane(
            name: "Pane \(paneCounter)",
            shell: targetPane?.shell ?? "/bin/zsh",
            workingDirectory: targetPane?.workingDirectory
        )
        if rootNode.split(paneID: paneID, direction: direction, newPane: newPane) {
            focusedPaneID = newPane.id
            return newPane
        }
        return nil
    }

    public func removePane(id: UUID) {
        let panes = allPanes
        guard panes.count > 1 else { return }
        if rootNode.removePane(id: id) {
            if focusedPaneID == id {
                focusedPaneID = allPanes.first?.id
            }
        }
    }

    public func focusPane(id: UUID) {
        guard allPanes.contains(where: { $0.id == id }) else { return }
        focusedPaneID = id
    }
}

extension Tab: Codable {
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
