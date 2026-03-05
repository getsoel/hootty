import Foundation

@Observable
public final class KanbanCard: Identifiable {
    public let id: UUID
    public var title: String
    public var cardDescription: String
    public internal(set) var laneID: UUID
    public internal(set) var sortOrder: Int

    public init(id: UUID = UUID(), title: String, cardDescription: String = "", laneID: UUID, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.cardDescription = cardDescription
        self.laneID = laneID
        self.sortOrder = sortOrder
    }
}

extension KanbanCard: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, cardDescription, laneID, sortOrder
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            cardDescription: try container.decode(String.self, forKey: .cardDescription),
            laneID: try container.decode(UUID.self, forKey: .laneID),
            sortOrder: try container.decode(Int.self, forKey: .sortOrder)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(cardDescription, forKey: .cardDescription)
        try container.encode(laneID, forKey: .laneID)
        try container.encode(sortOrder, forKey: .sortOrder)
    }
}
