import SwiftUI
import KlaudeCore

struct ContentView: View {
    var appModel: AppModel
    @State private var selectedSessionID: UUID?

    private var selectedSession: Session? {
        appModel.sessions.first { $0.id == selectedSessionID }
    }

    private var theme: TerminalTheme {
        appModel.themeManager.theme
    }

    var body: some View {
        HStack(spacing: 0) {
            if appModel.sidebarVisible {
                SessionSidebar(
                    sessions: appModel.sessions,
                    selectedSessionID: $selectedSessionID,
                    theme: theme,
                    onAddSession: {
                        let session = appModel.addSession()
                        selectedSessionID = session.id
                    },
                    onRemoveSession: { id in
                        appModel.removeSession(id: id)
                        if selectedSessionID == id {
                            selectedSessionID = appModel.sessions.first?.id
                        }
                    }
                )
                .transition(.move(edge: .leading))

                // Divider between sidebar and terminal
                Rectangle()
                    .fill(Color(theme.sidebarSurface))
                    .frame(width: 1)
            }

            // Detail view
            if let session = selectedSession {
                TerminalPanel(session: session)
                    .id(session.id)
            } else {
                Text("Select or create a session")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.sidebarVisible)
        .onAppear {
            selectedSessionID = appModel.sessions.first?.id
        }
    }
}
