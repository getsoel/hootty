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

    /// Transition a pane out of the thinking state. If it was thinking and is now
    /// unfocused (and not manually flagged), sets `.done` attention.
    private func endThinking(_ workspace: Workspace, _ pane: Pane) {
        let wasThinking = pane.isThinking
        pane.isThinking = false
        if wasThinking {
            let isFocused = workspace.id == selectedWorkspaceID()
                && workspace.focusedPaneID == pane.id
            if !isFocused { pane.attentionKind = .done }
        }
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
            guard !pane.isThinking else { return false }
            pane.attentionKind = .bell
            return true
        } ?? false
    }

    public func handlePaneThinkingChanged(_ paneID: UUID, isThinking: Bool) {
        withPane(id: paneID) { workspace, pane in
            if isThinking {
                pane.isThinking = true
                pane.attentionKind = nil
            } else {
                endThinking(workspace, pane)
            }
        }
    }

    public func handleTitleChange(_ paneID: UUID, title: String) {
        withPane(id: paneID) { workspace, pane in
            guard let presence = AgentTitleDetection.detect(title) else {
                // Title no longer matches any agent pattern. If the pane has
                // an auto-detected agent session and was thinking, treat this
                // as an implicit idle transition (e.g. Codex, which has no
                // dedicated idle glyph). Preserve the session marker — there
                // is no reliable way to distinguish "agent went idle" from
                // "agent quit" via title alone, so clearing is deferred to
                // `processDidExit`.
                if pane.agentSessionID == "auto", pane.isThinking {
                    endThinking(workspace, pane)
                }
                return
            }

            if pane.agentSessionID == nil {
                pane.agentSessionID = "auto"
            }

            switch presence {
            case .thinking:
                pane.isThinking = true
                pane.attentionKind = nil
            case .idle:
                endThinking(workspace, pane)
            case .needsAttention:
                pane.isThinking = false
                _ = handlePaneNeedsAttention(paneID, kind: .done)
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
