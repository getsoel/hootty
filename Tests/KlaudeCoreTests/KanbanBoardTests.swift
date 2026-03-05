import Testing
import Foundation
@testable import KlaudeCore

@Suite struct KanbanBoardTests {
    @Test func defaultBoardHasFiveLanes() {
        let board = KanbanBoard.defaultBoard()
        #expect(board.lanes.count == 5)
        #expect(board.lanes.map(\.name) == ["Research", "Planning", "In Progress", "Review", "Done"])
    }

    @Test func addCardAppendsToLane() {
        let board = KanbanBoard.defaultBoard()
        let laneID = board.lanes[0].id
        let card = board.addCard(title: "Test Card", laneID: laneID)
        #expect(board.cards.count == 1)
        #expect(card.title == "Test Card")
        #expect(card.laneID == laneID)
    }

    @Test func moveCardBetweenLanes() {
        let board = KanbanBoard.defaultBoard()
        let sourceLane = board.lanes[0].id
        let targetLane = board.lanes[1].id
        let card = board.addCard(title: "Moveable", laneID: sourceLane)
        board.moveCard(card.id, toLane: targetLane, atIndex: 0)
        #expect(card.laneID == targetLane)
        #expect(board.cards(for: sourceLane).isEmpty)
        #expect(board.cards(for: targetLane).count == 1)
    }

    @Test func removeCard() {
        let board = KanbanBoard.defaultBoard()
        let laneID = board.lanes[0].id
        let card = board.addCard(title: "To Remove", laneID: laneID)
        board.removeCard(card.id)
        #expect(board.cards.isEmpty)
    }

    @Test func cardsSortedBySortOrder() {
        let board = KanbanBoard.defaultBoard()
        let laneID = board.lanes[0].id
        let card1 = board.addCard(title: "First", laneID: laneID)
        let card2 = board.addCard(title: "Second", laneID: laneID)
        let card3 = board.addCard(title: "Third", laneID: laneID)
        let sorted = board.cards(for: laneID)
        #expect(sorted.map(\.id) == [card1.id, card2.id, card3.id])
    }

    @Test func updateCard() {
        let board = KanbanBoard.defaultBoard()
        let laneID = board.lanes[0].id
        let card = board.addCard(title: "Original", laneID: laneID)
        board.updateCard(card.id, title: "Updated", description: "A description")
        #expect(card.title == "Updated")
        #expect(card.cardDescription == "A description")
    }

    @Test func jsonRoundTrip() throws {
        let board = KanbanBoard.defaultBoard()
        let laneID = board.lanes[0].id
        board.addCard(title: "Persisted", laneID: laneID)
        board.addCard(title: "Also Persisted", laneID: board.lanes[2].id)

        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(KanbanBoard.self, from: data)

        #expect(decoded.lanes.count == 5)
        #expect(decoded.cards.count == 2)
        #expect(decoded.lanes.map(\.name) == board.lanes.map(\.name))
        #expect(decoded.cards[0].title == "Persisted")
        #expect(decoded.cards[1].title == "Also Persisted")
    }

    @Test func moveCardReordersSortOrders() {
        let board = KanbanBoard.defaultBoard()
        let laneID = board.lanes[0].id
        let card1 = board.addCard(title: "A", laneID: laneID)
        let card2 = board.addCard(title: "B", laneID: laneID)
        let card3 = board.addCard(title: "C", laneID: laneID)
        // Move card3 to index 0
        board.moveCard(card3.id, toLane: laneID, atIndex: 0)
        let sorted = board.cards(for: laneID)
        #expect(sorted.map(\.id) == [card3.id, card1.id, card2.id])
    }
}
