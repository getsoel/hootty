import Foundation

@Observable
public final class PaneGroup: Identifiable {
    public let id: UUID
    public var name: String
    public var customName: String?
    public var panes: [Pane]
    public var selectedPaneID: UUID?
    private var paneCounter = 0

    public var isRunning: Bool {
        panes.contains { $0.isRunning }
    }

    public var needsAttention: Bool {
        panes.contains { $0.needsAttention }
    }

    public var selectedPane: Pane? {
        guard let selectedPaneID else { return panes.first }
        return panes.first { $0.id == selectedPaneID } ?? panes.first
    }

    public var displayName: String {
        customName ?? name
    }

    public init(name: String, customName: String? = nil, shell: String = "/bin/zsh", workingDirectory: String? = nil) {
        self.id = UUID()
        self.name = name
        self.customName = customName
        let pane = Pane(name: name, shell: shell, workingDirectory: workingDirectory)
        self.panes = [pane]
        self.selectedPaneID = pane.id
        self.paneCounter = 1
    }

    /// Restoration initializer for decoding persisted state.
    public init(id: UUID, name: String, customName: String? = nil, panes: [Pane], selectedPaneID: UUID?) {
        self.id = id
        self.name = name
        self.customName = customName
        self.panes = panes
        self.selectedPaneID = selectedPaneID
        self.paneCounter = panes.count
    }

    @discardableResult
    public func addPane(shell: String = "/bin/zsh", workingDirectory: String? = nil) -> Pane {
        paneCounter += 1
        let pane = Pane(
            name: "Pane \(paneCounter)",
            shell: shell,
            workingDirectory: workingDirectory ?? selectedPane?.workingDirectory
        )
        panes.append(pane)
        selectedPaneID = pane.id
        return pane
    }

    public func removePane(id: UUID) {
        guard let index = panes.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedPaneID == id
        panes.remove(at: index)

        if panes.isEmpty {
            selectedPaneID = nil
        } else if wasSelected {
            let newIndex = min(index, panes.count - 1)
            selectedPaneID = panes[newIndex].id
        }
    }

    public func selectPane(id: UUID) {
        guard let pane = panes.first(where: { $0.id == id }) else { return }
        selectedPaneID = id
        pane.needsAttention = false
    }

    public func selectPreviousPane() {
        guard panes.count > 1, let index = selectedPaneIndex else { return }
        let newIndex = index > 0 ? index - 1 : panes.count - 1
        selectPane(id: panes[newIndex].id)
    }

    public func selectNextPane() {
        guard panes.count > 1, let index = selectedPaneIndex else { return }
        let newIndex = index < panes.count - 1 ? index + 1 : 0
        selectPane(id: panes[newIndex].id)
    }

    private var selectedPaneIndex: Int? {
        guard let id = selectedPaneID else { return nil }
        return panes.firstIndex(where: { $0.id == id })
    }

    public func movePane(fromID: UUID, toID: UUID) {
        guard fromID != toID,
              let fromIndex = panes.firstIndex(where: { $0.id == fromID }),
              let toIndex = panes.firstIndex(where: { $0.id == toID })
        else { return }
        let pane = panes.remove(at: fromIndex)
        let newToIndex = panes.firstIndex(where: { $0.id == toID }) ?? panes.endIndex
        panes.insert(pane, at: toIndex > fromIndex ? newToIndex + 1 : newToIndex)
    }
}

extension PaneGroup: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, customName, panes, selectedPaneID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            customName: try container.decodeIfPresent(String.self, forKey: .customName),
            panes: try container.decode([Pane].self, forKey: .panes),
            selectedPaneID: try container.decodeIfPresent(UUID.self, forKey: .selectedPaneID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encode(panes, forKey: .panes)
        try container.encode(selectedPaneID, forKey: .selectedPaneID)
    }
}
