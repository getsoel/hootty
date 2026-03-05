import SwiftUI
import PrompttyCore

struct KanbanCardView: View {
    let card: KanbanCard
    let theme: TerminalTheme
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(theme.foreground))
                .lineLimit(2)

            if !card.cardDescription.isEmpty {
                Text(card.cardDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(theme.sidebarTextSecondary))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(theme.sidebarSurface))
        )
        .draggable(card.id.uuidString)
        .contextMenu {
            Button("Edit Card") { onEdit() }
            Divider()
            Button("Delete Card") { onDelete() }
        }
    }
}
