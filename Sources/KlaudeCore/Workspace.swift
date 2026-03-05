import Foundation

@Observable
public final class Workspace: Identifiable {
    public let id = UUID()
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

    public init(name: String) {
        self.name = name
        addTab()
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
            addTab()
        } else if wasSelected {
            // Select nearest neighbor
            let newIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[newIndex].id
        }
    }

    public func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
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
