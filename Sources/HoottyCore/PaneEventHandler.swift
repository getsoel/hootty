import Foundation

/// Handles terminal pane events (attention, bell, title changes, pwd changes).
/// Extracted from AppModel to separate event handling from workspace management.
@MainActor
public final class PaneEventHandler {
    private let findPane: (UUID) -> (Workspace, Pane)?
    private let selectedWorkspaceID: () -> UUID?
    private let debouncedSave: () -> Void

    public init(
        findPane: @escaping (UUID) -> (Workspace, Pane)?,
        selectedWorkspaceID: @escaping () -> UUID?,
        debouncedSave: @escaping () -> Void
    ) {
        self.findPane = findPane
        self.selectedWorkspaceID = selectedWorkspaceID
        self.debouncedSave = debouncedSave
    }

    @discardableResult
    private func withPane<T>(id: UUID, _ body: (Workspace, Pane) -> T) -> T? {
        guard let (workspace, pane) = findPane(id) else { return nil }
        return body(workspace, pane)
    }

    private func isFocused(_ workspace: Workspace, _ pane: Pane) -> Bool {
        workspace.id == selectedWorkspaceID() && workspace.focusedPaneID == pane.id
    }

    /// Apply a presence event to a pane. Returns the attention kind to
    /// announce with a sound, if any (see `PanePresence.apply`).
    @discardableResult
    private func update(_ workspace: Workspace, _ pane: Pane, _ event: PresenceEvent) -> AttentionKind? {
        pane.updatePresence(event, isFocused: isFocused(workspace, pane))
    }

    private func markAgentSession(_ pane: Pane) {
        if pane.agentSessionID == nil {
            pane.agentSessionID = Pane.autoSessionID
        }
    }

    /// Terminal bell (BEL). Ignored while the program is working.
    @discardableResult
    public func handleBell(_ paneID: UUID) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            update(workspace, pane, .bell)
        } ?? nil
    }

    /// A desktop notification (OSC 9/777) that isn't a hootty protocol message.
    @discardableResult
    public func handleNotification(_ paneID: UUID) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            update(workspace, pane, .notification)
        } ?? nil
    }

    @discardableResult
    public func handleTitleChange(_ paneID: UUID, title: String) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            let glyph = AgentTitleDetection.detect(title)
            if glyph != nil {
                markAgentSession(pane)
            } else if pane.agentSessionID == Pane.autoSessionID, !pane.isThinking,
                      pane.programStatus.isEmpty {
                // Not working and the title no longer matches: the agent
                // exited. Clear the marker so the sidebar and title bar revert
                // to plain terminal style. (A no-match while working is an
                // implicit idle, e.g. Codex, which has no idle glyph.)
                pane.agentSessionID = nil
                pane.agentName = nil
            }
            return update(workspace, pane, .title(glyph))
        } ?? nil
    }

    /// Process an explicit hootty protocol presence message from a TUI tool.
    /// Unlike title-based detection, this is an opt-in contract via OSC 9.
    @discardableResult
    public func handleHoottyPresence(_ paneID: UUID, presence: AgentPresence) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            markAgentSession(pane)
            return update(workspace, pane, .hook(presence))
        } ?? nil
    }

    /// Process an OSC 9;4 progress report as a presence signal.
    ///
    /// Claude Code brackets each turn with `9;4;3` (indeterminate) and `9;4;0`
    /// (remove), which survives the title being disabled or renamed. But OSC 9;4
    /// is not agent-specific — package managers and download tools emit it too —
    /// so this only refines panes already known to be running an agent. It never
    /// promotes a plain terminal to an agent pane the way the title and hootty
    /// protocol paths do.
    @discardableResult
    public func handleProgressReport(_ paneID: UUID, isBusy: Bool) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            guard pane.agentSessionID != nil else { return nil }
            return update(workspace, pane, .progressReport(isBusy: isBusy))
        } ?? nil
    }

    /// Process an explicit hootty protocol error message from a TUI tool.
    @discardableResult
    public func handleHoottyError(_ paneID: UUID) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            markAgentSession(pane)
            return update(workspace, pane, .hookError)
        } ?? nil
    }

    /// Apply an OSC 7501 program status report. While a pane has records they
    /// decide its live activity alone (see `PanePresence.activity`).
    @discardableResult
    public func handleProgramStatus(_ paneID: UUID, report: ProgramStatusReport) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            update(workspace, pane, .programStatus(report))
        } ?? nil
    }

    /// A command finished and the shell is back at its prompt: whatever was
    /// running has ended, so every live signal is dropped (OSC 7501 keeps its
    /// done/error records until seen, per the spec's lifetime rules).
    @discardableResult
    public func handleCommandFinished(_ paneID: UUID) -> AttentionKind? {
        withPane(id: paneID) { workspace, pane in
            update(workspace, pane, .commandFinished)
        } ?? nil
    }

    public func handlePwdChanged(_ paneID: UUID, pwd: String) {
        withPane(id: paneID) { workspace, pane in
            let newBranch = GitWorktreeManager.currentBranch(for: pwd)

            // Short-circuit: non-git directory and pane already has no branch — skip extra subprocess calls
            if newBranch == nil && pane.branch == nil {
                return
            }

            let canonicalRoot = GitWorktreeManager.canonicalRepoRoot(for: pwd)
            let showToplevel = GitWorktreeManager.repoRoot(for: pwd)
            let newWorktreePath = GitWorktreeManager.isWorktree(for: pwd) ? showToplevel : nil
            var changed = false
            if pane.branch != newBranch {
                pane.branch = newBranch
                changed = true
            }
            if pane.repoRoot != canonicalRoot {
                pane.repoRoot = canonicalRoot
                changed = true
            }
            if pane.worktreePath != newWorktreePath {
                pane.worktreePath = newWorktreePath
                changed = true
            }
            if newWorktreePath == nil, let root = canonicalRoot, let branch = newBranch,
               workspace.headBranches[root] != branch {
                workspace.headBranches[root] = branch
                changed = true
            }
            if workspace.repoPath == nil, let root = canonicalRoot {
                workspace.repoPath = root
                changed = true
            }
            if changed { debouncedSave() }
        }
    }
}
