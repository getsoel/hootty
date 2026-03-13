import Testing
import Foundation
@testable import HoottyCore

@Suite struct BranchListTests {

    // MARK: - Parsing

    @Test func parsesLocalBranches() {
        let output = """
        main\t\t*
        feature-auth\torigin/feature-auth\t
        fix-bug-123\t\t
        """
        let (locals, remotes, head) = GitWorktreeManager.parseBranchList(output)

        #expect(locals.count == 3)
        #expect(head == "main")

        #expect(locals[0].name == "main")
        #expect(locals[0].isHead == true)
        #expect(locals[0].isRemote == false)
        #expect(locals[0].upstream == nil)

        #expect(locals[1].name == "feature-auth")
        #expect(locals[1].isHead == false)
        #expect(locals[1].upstream == "origin/feature-auth")

        #expect(locals[2].name == "fix-bug-123")
        #expect(locals[2].isHead == false)

        #expect(remotes.isEmpty)
    }

    @Test func parsesRemoteBranches() {
        let output = """
        main\t\t*
        origin/main\t\t
        origin/feature-ui\t\t
        origin/HEAD\t\t
        """
        let (locals, remotes, head) = GitWorktreeManager.parseBranchList(output)

        #expect(locals.count == 1)
        #expect(head == "main")

        // origin/HEAD is filtered out
        #expect(remotes.count == 2)
        #expect(remotes[0].name == "main")
        #expect(remotes[0].isRemote == true)
        #expect(remotes[1].name == "feature-ui")
        #expect(remotes[1].isRemote == true)
    }

    @Test func parsesEmptyOutput() {
        let (locals, remotes, head) = GitWorktreeManager.parseBranchList("")
        #expect(locals.isEmpty)
        #expect(remotes.isEmpty)
        #expect(head == nil)
    }

    @Test func noHeadBranch() {
        let output = """
        feature-auth\torigin/feature-auth\t
        fix-bug-123\t\t
        """
        let (locals, _, head) = GitWorktreeManager.parseBranchList(output)
        #expect(locals.count == 2)
        #expect(head == nil)
    }

    // MARK: - Cross-reference with pane branches

    @Test func listBranchesCrossReferencesPanes() {
        let ws = Workspace(name: "Test")
        ws.repoPath = "/tmp/fake-repo"

        let p1 = ws.allPanes[0]
        p1.branch = "main"
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        p2.branch = "feature-auth"

        // Build cross-reference manually (same logic as listBranches)
        var panesByBranchName: [String: [UUID]] = [:]
        for pane in ws.allPanes {
            if let branch = pane.branch {
                panesByBranchName[branch, default: []].append(pane.id)
            }
        }

        let refs = [
            BranchRef(name: "main", isHead: true),
            BranchRef(name: "feature-auth"),
            BranchRef(name: "fix-bug-123"),
        ]

        let crossReferenced = refs.map { ref -> BranchRef in
            var branch = ref
            if let paneIDs = panesByBranchName[ref.name] {
                branch.hasPanes = true
                branch.paneIDs = paneIDs
            }
            return branch
        }

        #expect(crossReferenced[0].hasPanes == true)
        #expect(crossReferenced[0].paneIDs == [p1.id])

        #expect(crossReferenced[1].hasPanes == true)
        #expect(crossReferenced[1].paneIDs == [p2.id])

        #expect(crossReferenced[2].hasPanes == false)
        #expect(crossReferenced[2].paneIDs.isEmpty)
    }

    @Test func nonGitWorkspaceReturnsEmptyBranches() {
        let ws = Workspace(name: "Scratch")
        #expect(ws.repoPath == nil)
        #expect(ws.listBranches().isEmpty)
    }

    // MARK: - BranchRef identity

    @Test func branchRefIdUniquenessLocalVsRemote() {
        let local = BranchRef(name: "main", isRemote: false)
        let remote = BranchRef(name: "main", isRemote: true)
        #expect(local.id != remote.id)
        #expect(local.id == "main")
        #expect(remote.id == "remote/main")
    }

    // MARK: - Remote filtering

    @Test func remoteBranchesExcludeLocalCounterparts() {
        let output = """
        main\t\t*
        feature-auth\t\t
        origin/main\t\t
        origin/feature-auth\t\t
        origin/remote-only\t\t
        """
        let (locals, remotes, _) = GitWorktreeManager.parseBranchList(output)

        // After filtering (which Workspace.listBranches does)
        let localNames = Set(locals.map(\.name))
        let filtered = remotes.filter { !localNames.contains($0.name) }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "remote-only")
    }
}
