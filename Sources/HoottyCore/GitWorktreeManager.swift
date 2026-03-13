import Foundation

/// A single git branch reference.
public struct BranchRef: Identifiable, Sendable {
    /// Branch name — unique within local or remote namespace.
    public let id: String
    /// Short name ("feature-auth").
    public let name: String
    public let isHead: Bool
    public let isRemote: Bool
    /// Tracking branch name, if any.
    public let upstream: String?
    /// Whether any panes are on this branch.
    public var hasPanes: Bool
    /// The pane UUIDs on this branch, if any.
    public var paneIDs: [UUID]

    public init(
        name: String,
        isHead: Bool = false,
        isRemote: Bool = false,
        upstream: String? = nil,
        hasPanes: Bool = false,
        paneIDs: [UUID] = []
    ) {
        self.id = (isRemote ? "remote/" : "") + name
        self.name = name
        self.isHead = isHead
        self.isRemote = isRemote
        self.upstream = upstream
        self.hasPanes = hasPanes
        self.paneIDs = paneIDs
    }
}

public struct GitWorktreeInfo: Sendable {
    public let path: String
    public let branch: String?
    public let isHead: Bool

    public init(path: String, branch: String?, isHead: Bool) {
        self.path = path
        self.branch = branch
        self.isHead = isHead
    }
}

/// Thin wrapper around `git worktree` CLI commands.
public enum GitWorktreeManager {
    /// Detect repo root from a directory path.
    public static func repoRoot(for path: String) -> String? {
        run(["git", "-C", path, "rev-parse", "--show-toplevel"])
    }

    /// Canonical repo root that resolves to the same path for both main checkouts and worktrees.
    /// Uses `--git-common-dir` → parent directory, unlike `--show-toplevel` which returns the worktree root.
    public static func canonicalRepoRoot(for path: String) -> String? {
        guard let commonDir = run(["git", "-C", path, "rev-parse", "--git-common-dir"]) else {
            return nil
        }
        // --git-common-dir returns the .git directory (absolute or relative).
        // The repo root is its parent.
        let resolved = (commonDir as NSString).standardizingPath
        let gitURL = URL(fileURLWithPath: resolved, relativeTo: URL(fileURLWithPath: path))
        return gitURL.standardizedFileURL.deletingLastPathComponent().path
    }

    /// Current branch name for a path.
    public static func currentBranch(for path: String) -> String? {
        run(["git", "-C", path, "branch", "--show-current"])
    }

    /// Returns true if the path is inside a git worktree (not the main working tree).
    public static func isWorktree(for path: String) -> Bool {
        guard let gitDir = run(["git", "-C", path, "rev-parse", "--git-dir"]),
              let commonDir = run(["git", "-C", path, "rev-parse", "--git-common-dir"]) else {
            return false
        }
        // In a worktree, --git-dir points to .git/worktrees/<name>, while --git-common-dir points to .git
        // Resolve to absolute paths for comparison — relative paths from subfolders won't match
        // with standardizingPath alone (it doesn't resolve ".." in relative paths)
        let base = URL(fileURLWithPath: path)
        let resolvedGit = URL(fileURLWithPath: (gitDir as NSString).standardizingPath, relativeTo: base).standardizedFileURL.path
        let resolvedCommon = URL(fileURLWithPath: (commonDir as NSString).standardizingPath, relativeTo: base).standardizedFileURL.path
        return resolvedGit != resolvedCommon
    }

    /// List existing worktrees for a repo.
    public static func listWorktrees(repoPath: String) -> [GitWorktreeInfo] {
        guard let output = run(["git", "-C", repoPath, "worktree", "list", "--porcelain"]) else {
            return []
        }
        return parseWorktreeList(output)
    }

    /// Create a new worktree with a new branch.
    @discardableResult
    public static func createWorktree(repoPath: String, branch: String, path: String) -> Bool {
        run(["git", "-C", repoPath, "worktree", "add", path, "-b", branch]) != nil
    }

    /// Create a worktree from an existing branch.
    @discardableResult
    public static func createWorktreeFromBranch(repoPath: String, branch: String, path: String) -> Bool {
        run(["git", "-C", repoPath, "worktree", "add", path, branch]) != nil
    }

    /// Remove a worktree.
    @discardableResult
    public static func removeWorktree(repoPath: String, path: String) -> Bool {
        run(["git", "-C", repoPath, "worktree", "remove", path]) != nil
    }

    /// List all branches (local + remote) for a repo.
    public static func listBranches(repoPath: String) -> (local: [BranchRef], remote: [BranchRef], head: String?) {
        guard let output = run([
            "git", "-C", repoPath, "for-each-ref",
            "--sort=-committerdate",
            "--format=%(refname:short)\t%(upstream:short)\t%(HEAD)",
            "refs/heads/", "refs/remotes/origin/"
        ]) else {
            return ([], [], nil)
        }
        return parseBranchList(output)
    }

    /// Delete a local branch.
    @discardableResult
    public static func deleteBranch(repoPath: String, branch: String, force: Bool = false) -> Bool {
        let flag = force ? "-D" : "-d"
        return run(["git", "-C", repoPath, "branch", flag, branch]) != nil
    }

    // MARK: - Branch Parsing

    /// Visible for testing.
    public static func parseBranchList(_ output: String) -> (local: [BranchRef], remote: [BranchRef], head: String?) {
        var locals: [BranchRef] = []
        var remotes: [BranchRef] = []
        var head: String?

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }

            let refName = parts[0]
            let upstream = parts[1].isEmpty ? nil : parts[1]
            let isHead = parts[2].trimmingCharacters(in: .whitespaces) == "*"

            if refName.hasPrefix("origin/") {
                let shortName = String(refName.dropFirst("origin/".count))
                // Skip HEAD pointer
                if shortName == "HEAD" { continue }
                remotes.append(BranchRef(
                    name: shortName,
                    isHead: false,
                    isRemote: true,
                    upstream: nil
                ))
            } else {
                if isHead { head = refName }
                locals.append(BranchRef(
                    name: refName,
                    isHead: isHead,
                    upstream: upstream
                ))
            }
        }
        return (locals, remotes, head)
    }

    // MARK: - Worktree Resolution

    /// Returns the filesystem path for a branch's worktree.
    /// If the branch is already checked out (HEAD or existing worktree), returns that path.
    /// Otherwise creates a new worktree and returns its path. Returns nil on failure.
    public static func resolveWorktreePath(repoPath: String, branch: String) -> String? {
        // Check existing worktrees first
        let worktrees = listWorktrees(repoPath: repoPath)
        if let existing = worktrees.first(where: { $0.branch == branch }) {
            return existing.path
        }

        // Create new worktree — matches Claude Code convention (.claude/worktrees/)
        let worktreeDir = (repoPath as NSString).appendingPathComponent(".claude/worktrees")
        let worktreePath = (worktreeDir as NSString).appendingPathComponent(branch)

        // Ensure parent directory exists
        try? FileManager.default.createDirectory(
            atPath: worktreeDir,
            withIntermediateDirectories: true
        )

        // Try existing branch first, fall back to creating new branch
        if createWorktreeFromBranch(repoPath: repoPath, branch: branch, path: worktreePath) {
            return worktreePath
        }
        if createWorktree(repoPath: repoPath, branch: branch, path: worktreePath) {
            return worktreePath
        }
        return nil
    }

    // MARK: - Private

    @discardableResult
    private static func run(_ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static func parseWorktreeList(_ output: String) -> [GitWorktreeInfo] {
        var results: [GitWorktreeInfo] = []
        var currentPath: String?
        var currentBranch: String?
        var isHead = false

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("worktree ") {
                if let path = currentPath {
                    results.append(GitWorktreeInfo(path: path, branch: currentBranch, isHead: isHead))
                }
                currentPath = String(line.dropFirst("worktree ".count))
                currentBranch = nil
                isHead = false
            } else if line.hasPrefix("branch refs/heads/") {
                currentBranch = String(line.dropFirst("branch refs/heads/".count))
            } else if line == "HEAD" {
                isHead = true
            }
        }

        if let path = currentPath {
            results.append(GitWorktreeInfo(path: path, branch: currentBranch, isHead: isHead))
        }

        return results
    }
}
