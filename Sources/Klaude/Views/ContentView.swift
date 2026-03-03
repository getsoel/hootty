import SwiftUI

struct ContentView: View {
    var appModel: AppModel
    @State private var selectedSessionID: UUID?

    private var selectedSession: Session? {
        appModel.sessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        NavigationSplitView {
            SessionSidebar(
                sessions: appModel.sessions,
                selectedSessionID: $selectedSessionID,
                onAddSession: {
                    let session = appModel.addSession()
                    selectedSessionID = session.id
                },
                onRemoveSession: { offsets in
                    appModel.removeSession(at: offsets)
                    if let id = selectedSessionID,
                       !appModel.sessions.contains(where: { $0.id == id }) {
                        selectedSessionID = appModel.sessions.first?.id
                    }
                }
            )
        } detail: {
            if let session = selectedSession {
                TerminalPanel(session: session, theme: appModel.themeManager.theme)
                    .id(session.id)
            } else {
                Text("Select or create a session")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            selectedSessionID = appModel.sessions.first?.id
        }
    }
}
