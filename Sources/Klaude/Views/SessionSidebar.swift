import SwiftUI

struct SessionSidebar: View {
    let sessions: [Session]
    @Binding var selectedSessionID: UUID?
    var onAddSession: () -> Void
    var onRemoveSession: (IndexSet) -> Void

    var body: some View {
        List(selection: $selectedSessionID) {
            ForEach(sessions) { session in
                HStack {
                    Circle()
                        .fill(session.isRunning ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(session.name)
                }
                .tag(session.id)
            }
            .onDelete(perform: onRemoveSession)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        .toolbar {
            ToolbarItem {
                Button(action: onAddSession) {
                    Label("New Session", systemImage: "plus")
                }
            }
        }
    }
}
