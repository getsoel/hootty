import SwiftUI
import HoottyCore

struct KanbanBoardView: View {
    let store: KanbanStore
    let theme: TerminalTheme

    @State private var editingCard: KanbanCard?
    @State private var editTitle = ""
    @State private var editDescription = ""

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(store.board.lanes.sorted(by: { $0.sortOrder < $1.sortOrder })) { lane in
                    KanbanLaneView(
                        lane: lane,
                        cards: store.board.cards(for: lane.id),
                        theme: theme,
                        onAddCard: { title in
                            store.board.addCard(title: title, laneID: lane.id)
                            store.save()
                        },
                        onMoveCard: { cardID, index in
                            store.board.moveCard(cardID, toLane: lane.id, atIndex: index)
                            store.save()
                        },
                        onEditCard: { card in
                            editTitle = card.title
                            editDescription = card.cardDescription
                            editingCard = card
                        },
                        onDeleteCard: { cardID in
                            store.board.removeCard(cardID)
                            store.save()
                        }
                    )
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(theme.background))
        .alert("Edit Card", isPresented: Binding(
            get: { editingCard != nil },
            set: { if !$0 { editingCard = nil } }
        )) {
            TextField("Title", text: $editTitle)
            TextField("Description", text: $editDescription)
            Button("Save") {
                if let card = editingCard {
                    store.board.updateCard(card.id, title: editTitle, description: editDescription)
                    store.save()
                }
                editingCard = nil
            }
            Button("Cancel", role: .cancel) { editingCard = nil }
        }
    }
}
