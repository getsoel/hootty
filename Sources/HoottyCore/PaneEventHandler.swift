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

    @discardableResult
    public func handlePaneNeedsAttention(_ paneID: UUID, kind: AttentionKind) -> Bool {
        withPane(id: paneID) { workspace, pane in
            let isFocusedPane = workspace.id == selectedWorkspaceID()
                && workspace.focusedPaneID == paneID
            if !isFocusedPane {
                pane.attentionKind = kind
                return true
            }
            return false
        } ?? false
    }

    @discardableResult
    public func handleBell(_ paneID: UUID) -> Bool {
        withPane(id: paneID) { _, pane in
            pane.attentionKind = .bell
            return true
        } ?? false
    }

    public func handlePaneThinkingChanged(_ paneID: UUID, isThinking: Bool) {
        withPane(id: paneID) { _, pane in
            pane.isThinking = isThinking
            if isThinking {
                pane.attentionKind = nil
            }
        }
    }

    public func handleTitleChange(_ paneID: UUID, title: String) {
        withPane(id: paneID) { _, pane in
            guard let state = ClaudeTitleParser.parse(title) else {
                // Title no longer matches Claude pattern — clear auto-detected session
                if pane.claudeSessionID == "auto" {
                    pane.claudeSessionID = nil
                    pane.isThinking = false
                }
                return
            }

            if pane.claudeSessionID == nil {
                pane.claudeSessionID = "auto"
            }

            switch state {
            case .thinking:
                if !pane.isThinking {
                    pane.isThinking = true
                    pane.attentionKind = nil
                }
            case .idle:
                if pane.isThinking { pane.isThinking = false }
            }
        }
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
