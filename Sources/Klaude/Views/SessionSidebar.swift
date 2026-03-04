import SwiftUI
import KlaudeCore

struct SessionSidebar: View {
    let sessions: [Session]
    @Binding var selectedSessionID: UUID?
    let theme: TerminalTheme
    var onAddSession: () -> Void
    var onRemoveSession: (UUID) -> Void

    @State private var hoveredSessionID: UUID?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)

            // Divider
            Rectangle()
                .fill(Color(theme.sidebarSurface))
                .frame(height: 1)

            // Add session button
            Button(action: onAddSession) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("New Session")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(theme.sidebarTextSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 200)
        .background(Color(theme.background))
        .alert("Rename Session", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Session name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let target = sessions.first(where: { $0.id == renameTargetID }) {
            target.name = trimmed
        }
        renameTargetID = nil
    }

    private func sessionRow(_ session: Session) -> some View {
        let isSelected = session.id == selectedSessionID
        let isHovered = session.id == hoveredSessionID
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(session.isRunning ? theme.sidebarRunningDot : theme.sidebarStoppedDot))
                .frame(width: 7, height: 7)

            Text(session.name)
                .font(.system(size: 13))
                .foregroundColor(Color(isSelected ? theme.foreground : theme.sidebarTextSecondary))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isHovered {
                Button {
                    onRemoveSession(session.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(theme.sidebarTextSecondary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color(theme.sidebarSurface)
                        : isHovered
                            ? Color(theme.sidebarSurface).opacity(0.4)
                            : Color.clear
                )
        )
        .onHover { hovering in
            hoveredSessionID = hovering ? session.id : nil
        }
        .onTapGesture {
            selectedSessionID = session.id
        }
        .contextMenu {
            Button("Rename") {
                editingName = session.name
                renameTargetID = session.id
            }
        }
    }
}
