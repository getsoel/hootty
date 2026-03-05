import Foundation

@Observable
public final class Workspace: Identifiable {
    public let id: UUID
    public var name: String
    public var tabs: [Tab] = []
    public var selectedTabID: UUID?
    private var tabCounter = 0

    public var selectedTab: Tab? {
        tabs.first { $0.id == selectedTabID }
    }

    public var isRunning: Bool {
        for tab in tabs {
            if tab.isRunning { return true }
        }
        return false
    }

    public var hasAttentionTab: Bool {
        for tab in tabs where tab.id != selectedTabID {
            if tab.needsAttention { return true }
        }
        return false
    }

    public init(name: String) {
        self.id = UUID()
        self.name = name
        addTab()
    }

    /// Restoration initializer for decoding persisted state.
    public init(id: UUID, name: String, tabs: [Tab], selectedTabID: UUID?) {
        self.id = id
        self.name = name
        self.tabs = tabs
        self.selectedTabID = selectedTabID
        self.tabCounter = tabs.count
    }

    @discardableResult
    public func addTab() -> Tab {
        tabCounter += 1
        let tab = Tab(name: "Tab \(tabCounter)")
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    public func removeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedTabID == id
        tabs.remove(at: index)

        if tabs.isEmpty {
            selectedTabID = nil
        } else if wasSelected {
            // Select nearest neighbor
            let newIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[newIndex].id
        }
    }

    public func selectTab(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        selectedTabID = id
        for pane in tab.allPanes {
            pane.needsAttention = false
        }
    }

    public func findPane(id: UUID) -> (Tab, Pane)? {
        for tab in tabs {
            if let pane = tab.allPanes.first(where: { $0.id == id }) {
                return (tab, pane)
            }
        }
        return nil
    }

    public func moveTab(fromID: UUID, toID: UUID) {
        guard fromID != toID,
              let fromIndex = tabs.firstIndex(where: { $0.id == fromID }),
              let toIndex = tabs.firstIndex(where: { $0.id == toID })
        else { return }
        let tab = tabs.remove(at: fromIndex)
        let newToIndex = tabs.firstIndex(where: { $0.id == toID }) ?? tabs.endIndex
        tabs.insert(tab, at: toIndex > fromIndex ? newToIndex + 1 : newToIndex)
    }
}

extension Workspace: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, tabs, selectedTabID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            tabs: try container.decode([Tab].self, forKey: .tabs),
            selectedTabID: try container.decodeIfPresent(UUID.self, forKey: .selectedTabID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tabs, forKey: .tabs)
        try container.encode(selectedTabID, forKey: .selectedTabID)
    }
}
