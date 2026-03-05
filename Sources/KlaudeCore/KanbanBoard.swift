import Foundation

@Observable
public final class KanbanBoard {
    public var lanes: [KanbanLane]
    public private(set) var cards: [KanbanCard]

    public init(lanes: [KanbanLane] = [], cards: [KanbanCard] = []) {
        self.lanes = lanes
        self.cards = cards
    }

    public static func defaultBoard() -> KanbanBoard {
        let laneNames = ["Research", "Planning", "In Progress", "Review", "Done"]
        let lanes = laneNames.enumerated().map { index, name in
            KanbanLane(name: name, sortOrder: index)
        }
        return KanbanBoard(lanes: lanes)
    }

    public func cards(for laneID: UUID) -> [KanbanCard] {
        cards.filter { $0.laneID == laneID }.sorted { $0.sortOrder < $1.sortOrder }
    }

    @discardableResult
    public func addCard(title: String, laneID: UUID) -> KanbanCard {
        let laneCards = cards(for: laneID)
        let nextOrder = (laneCards.last?.sortOrder ?? -1) + 1
        let card = KanbanCard(title: title, laneID: laneID, sortOrder: nextOrder)
        cards.append(card)
        return card
    }

    public func moveCard(_ cardID: UUID, toLane laneID: UUID, atIndex index: Int) {
        guard let card = cards.first(where: { $0.id == cardID }) else { return }
        card.laneID = laneID
        // Reorder cards in the target lane
        var laneCards = cards.filter { $0.laneID == laneID && $0.id != cardID }
            .sorted { $0.sortOrder < $1.sortOrder }
        let clampedIndex = min(index, laneCards.count)
        laneCards.insert(card, at: clampedIndex)
        for (i, c) in laneCards.enumerated() {
            c.sortOrder = i
        }
    }

    public func removeCard(_ cardID: UUID) {
        cards.removeAll { $0.id == cardID }
    }

    public func updateCard(_ cardID: UUID, title: String, description: String) {
        guard let card = cards.first(where: { $0.id == cardID }) else { return }
        card.title = title
        card.cardDescription = description
    }
}

extension KanbanBoard: Codable {
    enum CodingKeys: String, CodingKey {
        case lanes, cards
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            lanes: try container.decode([KanbanLane].self, forKey: .lanes),
            cards: try container.decode([KanbanCard].self, forKey: .cards)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lanes, forKey: .lanes)
        try container.encode(cards, forKey: .cards)
    }
}
