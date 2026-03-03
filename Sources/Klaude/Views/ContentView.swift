import SwiftUI

struct ContentView: View {
    @Binding var sessions: [Session]
    @State private var selectedSessionID: UUID?
    @State private var sessionCounter = 1

    private var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        NavigationSplitView {
            SessionSidebar(
                sessions: sessions,
                selectedSessionID: $selectedSessionID,
                onAddSession: addSession,
                onRemoveSession: removeSession
            )
        } detail: {
            if let session = selectedSession {
                VStack(spacing: 0) {
                    TerminalView(session: session.ptySession)
                    TerminalInputField(session: session.ptySession)
                }
            } else {
                Text("Select or create a session")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if let first = sessions.first {
                selectedSessionID = first.id
                first.ptySession.start()
            }
        }
    }

    private func addSession() {
        sessionCounter += 1
        let session = Session(name: "Session \(sessionCounter)")
        sessions.append(session)
        selectedSessionID = session.id
        session.ptySession.start()
    }

    private func removeSession(at offsets: IndexSet) {
        for i in offsets {
            sessions[i].ptySession.stop()
        }
        sessions.remove(atOffsets: offsets)
        if selectedSessionID != nil, !sessions.contains(where: { $0.id == selectedSessionID }) {
            selectedSessionID = sessions.first?.id
        }
    }
}
