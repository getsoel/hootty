import SwiftUI
import KlaudeCore

struct KanbanLaneView: View {
    let lane: KanbanLane
    let cards: [KanbanCard]
    let theme: TerminalTheme
    var onAddCard: (String) -> Void
    var onMoveCard: (UUID, Int) -> Void
    var onEditCard: (KanbanCard) -> Void
    var onDeleteCard: (UUID) -> Void

    @State private var newCardTitle = ""
    @State private var isAddingCard = false

    var body: some View {
        VStack(spacing: 0) {
            laneHeader
            cardList
        }
        .frame(width: 240)
        .background(Color(theme.background).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var laneHeader: some View {
        HStack {
            Text(lane.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(theme.foreground))

            Spacer()

            Text("\(cards.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(theme.sidebarTextSecondary))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color(theme.sidebarSurface))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var cardList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 6) {
                ForEach(cards) { card in
                    KanbanCardView(
                        card: card,
                        theme: theme,
                        onEdit: { onEditCard(card) },
                        onDelete: { onDeleteCard(card.id) }
                    )
                }

                addCardArea
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let cardIDString = items.first,
                  let cardID = UUID(uuidString: cardIDString) else { return false }
            onMoveCard(cardID, cards.count)
            return true
        }
    }

    private var addCardArea: some View {
        Group {
            if isAddingCard {
                VStack(spacing: 6) {
                    TextField("Card title", text: $newCardTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(theme.foreground))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(theme.sidebarSurface))
                        )
                        .onSubmit { commitNewCard() }

                    HStack(spacing: 6) {
                        Button("Add") { commitNewCard() }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(theme.foreground))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(theme.sidebarSurface))
                            )

                        Button("Cancel") {
                            isAddingCard = false
                            newCardTitle = ""
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(theme.sidebarTextSecondary))

                        Spacer()
                    }
                }
            } else {
                Button {
                    isAddingCard = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                        Text("Add Card")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(theme.sidebarTextSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitNewCard() {
        let trimmed = newCardTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onAddCard(trimmed)
        }
        newCardTitle = ""
        isAddingCard = false
    }
}
