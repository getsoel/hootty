import Foundation

// MARK: - Data Types

public enum WorkshopArtifactID: String, CaseIterable, Sendable {
    case proposal
    case specs
    case design
    case tasks

    public var displayName: String {
        switch self {
        case .proposal: "Proposal"
        case .specs: "Specs"
        case .design: "Design"
        case .tasks: "Tasks"
        }
    }
}

public enum WorkshopArtifactState: String, Sendable, Equatable {
    case blocked
    case ready
    case done
}

public struct WorkshopArtifact: Identifiable, Sendable, Equatable {
    public let id: WorkshopArtifactID
    public let state: WorkshopArtifactState

    public var displayName: String {
        id.displayName
    }

    public init(id: WorkshopArtifactID, state: WorkshopArtifactState) {
        self.id = id
        self.state = state
    }
}

public struct WorkshopChange: Identifiable, Sendable, Equatable {
    public let name: String
    public let displayName: String
    public let artifacts: [WorkshopArtifact]
    public let isArchived: Bool

    public var id: String {
        name
    }

    /// Convert a kebab-case name to title case (e.g., "add-user-auth" → "Add User Auth").
    public static func formatName(_ name: String) -> String {
        name.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    public init(name: String, artifacts: [WorkshopArtifact], isArchived: Bool = false) {
        self.name = name
        self.displayName = Self.formatName(name)
        self.artifacts = artifacts
        self.isArchived = isArchived
    }
}

public struct WorkshopRepoStatus: Sendable, Equatable {
    public let repoRoot: String
    public let changes: [WorkshopChange]
    public let isInitialized: Bool

    public init(repoRoot: String, changes: [WorkshopChange], isInitialized: Bool) {
        self.repoRoot = repoRoot
        self.changes = changes
        self.isInitialized = isInitialized
    }
}

// MARK: - Claims

public struct WorkshopClaim: Sendable, Equatable {
    public let change: String
    public let taskGroup: String?
    public let claimedAt: String

    public init(change: String, taskGroup: String? = nil, claimedAt: String) {
        self.change = change
        self.taskGroup = taskGroup
        self.claimedAt = claimedAt
    }
}

// MARK: - Task Progress

public struct WorkshopTaskGroup: Sendable, Equatable {
    public let name: String
    public let total: Int
    public let completed: Int

    public init(name: String, total: Int, completed: Int) {
        self.name = name
        self.total = total
        self.completed = completed
    }
}

// MARK: - Model

@MainActor
@Observable
public final class WorkshopModel {
    /// Relative path from repo root to the workshop directory.
    public static let directoryPath = "workshop"

    /// Relative path from repo root to the hootty claims directory.
    public static let claimsPath = ".hootty/claims"

    /// Workshop status per repo root.
    public private(set) var statusByRepo: [String: WorkshopRepoStatus] = [:]

    /// Claims per pane ID, keyed by UUID string. Merged across all repo roots.
    public private(set) var claimsByPaneID: [String: WorkshopClaim] = [:]

    /// Cached task groups per change name, refreshed alongside claims.
    public private(set) var taskGroupsByChange: [String: [WorkshopTaskGroup]] = [:]

    public init() {}

    public nonisolated static func hasWorkshop(repoRoot: String) -> Bool {
        var isDir: ObjCBool = false
        let path = (repoRoot as NSString).appendingPathComponent(directoryPath)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    public func status(for repoRoot: String) -> WorkshopRepoStatus? {
        statusByRepo[repoRoot]
    }

    public func removeStatus(for repoRoot: String) {
        statusByRepo.removeValue(forKey: repoRoot)
    }

    // MARK: - Refresh

    /// Refresh Workshop state by scanning the filesystem.
    /// Resolves artifact states from file existence using the hardcoded workshop-driven schema.
    /// Only updates `statusByRepo` if state actually changed (avoids spurious re-renders).
    public func refresh(repoRoot: String) {
        let workshopPath = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)

        guard FileManager.default.fileExists(atPath: workshopPath) else {
            let empty = WorkshopRepoStatus(repoRoot: repoRoot, changes: [], isInitialized: false)
            if statusByRepo[repoRoot] != empty {
                statusByRepo[repoRoot] = empty
            }
            return
        }

        var changes: [WorkshopChange] = []
        let changesDir = (workshopPath as NSString).appendingPathComponent("changes")
        changes.append(contentsOf: Self.scanDirectory(changesDir, isArchived: false))

        let archiveDir = (workshopPath as NSString).appendingPathComponent("archive")
        changes.append(contentsOf: Self.scanDirectory(archiveDir, isArchived: true))

        let newStatus = WorkshopRepoStatus(repoRoot: repoRoot, changes: changes, isInitialized: true)
        if statusByRepo[repoRoot] != newStatus {
            statusByRepo[repoRoot] = newStatus
        }
    }

    // MARK: - Claims

    public func claim(forPaneID paneID: String) -> WorkshopClaim? {
        claimsByPaneID[paneID]
    }

    /// Refresh claims by scanning `.hootty/claims/` and merging into the global map.
    /// Also caches task groups for any claimed changes.
    public func refreshClaims(repoRoot: String) {
        let claimsDir = (repoRoot as NSString).appendingPathComponent(Self.claimsPath)
        let repoClaims = Self.scanClaims(claimsDir)

        // Merge: remove stale claims from this repo, add/update current ones.
        var merged = claimsByPaneID
        for (paneID, existing) in merged {
            // Remove claims whose change belongs to this repo but isn't in the new scan
            if repoClaims[paneID] == nil, Self.changeExistsInRepo(existing.change, repoRoot: repoRoot) {
                merged.removeValue(forKey: paneID)
            }
        }
        for (paneID, claim) in repoClaims {
            merged[paneID] = claim
        }
        if merged != claimsByPaneID {
            claimsByPaneID = merged
        }

        // Cache task groups for claimed changes
        var newGroups = taskGroupsByChange
        let claimedChanges = Set(repoClaims.values.map(\.change))
        for changeName in claimedChanges {
            newGroups[changeName] = readTaskGroups(repoRoot: repoRoot, changeName: changeName)
        }
        if newGroups != taskGroupsByChange {
            taskGroupsByChange = newGroups
        }
    }

    private nonisolated static func changeExistsInRepo(_ changeName: String, repoRoot: String) -> Bool {
        let base = (repoRoot as NSString).appendingPathComponent(directoryPath)
        let changesDir = ((base as NSString).appendingPathComponent("changes") as NSString).appendingPathComponent(changeName)
        return FileManager.default.fileExists(atPath: changesDir)
    }

    /// Scan claims directory for all claim files.
    private nonisolated static func scanClaims(_ claimsDir: String) -> [String: WorkshopClaim] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: claimsDir) else { return [:] }

        var claims: [String: WorkshopClaim] = [:]
        for item in items where item.hasSuffix(".yaml") {
            let paneID = String(item.dropLast(5)) // remove .yaml
            let path = (claimsDir as NSString).appendingPathComponent(item)
            guard let data = fm.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else { continue }

            let parsed = parseSimpleYaml(content)
            guard let change = parsed["change"] else { continue }

            claims[paneID] = WorkshopClaim(
                change: change,
                taskGroup: parsed["taskGroup"],
                claimedAt: parsed["claimedAt"] ?? ""
            )
        }
        return claims
    }

    /// Minimal YAML parser for flat key-value claim files.
    private nonisolated static func parseSimpleYaml(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.split(separator: "\n") {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex ..< colonIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    // MARK: - Task Group Parsing

    /// Get cached task groups for a change. Returns empty if not cached.
    public func taskGroups(forChange changeName: String) -> [WorkshopTaskGroup] {
        taskGroupsByChange[changeName] ?? []
    }

    /// Read task groups from disk for a change's tasks.md.
    private nonisolated func readTaskGroups(repoRoot: String, changeName: String) -> [WorkshopTaskGroup] {
        let base = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)
        for subdir in ["changes", "archive"] {
            let tasksPath = (base as NSString)
                .appendingPathComponent(subdir)
                .appending("/\(changeName)/tasks.md")
            if let data = FileManager.default.contents(atPath: tasksPath),
               let content = String(data: data, encoding: .utf8) {
                return Self.parseTaskGroups(content)
            }
        }
        return []
    }

    /// Parse tasks.md content into task groups.
    private nonisolated static func parseTaskGroups(_ content: String) -> [WorkshopTaskGroup] {
        var groups: [WorkshopTaskGroup] = []
        var currentName: String?
        var total = 0
        var completed = 0

        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                // Flush previous group
                if let name = currentName {
                    groups.append(WorkshopTaskGroup(name: name, total: total, completed: completed))
                }
                currentName = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                total = 0
                completed = 0
            } else if line.contains("- [") {
                total += 1
                if line.contains("- [x]") || line.contains("- [X]") {
                    completed += 1
                }
            }
        }

        if let name = currentName {
            groups.append(WorkshopTaskGroup(name: name, total: total, completed: completed))
        }
        return groups
    }

    // MARK: - Private Helpers

    /// Scan a directory for change subdirectories, returning a WorkshopChange for each.
    private nonisolated static func scanDirectory(_ dirPath: String, isArchived: Bool) -> [WorkshopChange] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dirPath) else { return [] }

        return items.sorted().compactMap { item -> WorkshopChange? in
            guard !item.hasPrefix(".") else { return nil }
            let changePath = (dirPath as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: changePath, isDirectory: &isDir), isDir.boolValue else { return nil }
            let artifacts = resolveArtifacts(changePath: changePath)
            return WorkshopChange(name: item, artifacts: artifacts, isArchived: isArchived)
        }
    }

    // MARK: - Artifact Resolution (workshop-driven schema, hardcoded)

    /// Resolve artifact states from filesystem for the workshop-driven schema.
    /// DAG: proposal → specs → tasks, proposal → design → tasks
    /// Uses a single `contentsOfDirectory` per change to minimize syscalls.
    private nonisolated static func resolveArtifacts(changePath: String) -> [WorkshopArtifact] {
        let fm = FileManager.default
        let entries = Set((try? fm.contentsOfDirectory(atPath: changePath)) ?? [])

        let proposalDone = entries.contains("proposal.md")

        let specsDone: Bool = {
            let specsDir = (changePath as NSString).appendingPathComponent("specs")
            guard let dirs = try? fm.contentsOfDirectory(atPath: specsDir) else { return false }
            return dirs.contains { subdir in
                var isDir: ObjCBool = false
                let subdirPath = (specsDir as NSString).appendingPathComponent(subdir)
                guard fm.fileExists(atPath: subdirPath, isDirectory: &isDir), isDir.boolValue else { return false }
                return fm.fileExists(atPath: (subdirPath as NSString).appendingPathComponent("spec.md"))
            }
        }()

        let designDone = entries.contains("design.md")
        let tasksDone = entries.contains("tasks.md")

        func state(done: Bool, depsReady: Bool) -> WorkshopArtifactState {
            done ? .done : (depsReady ? .ready : .blocked)
        }

        return [
            WorkshopArtifact(id: .proposal, state: state(done: proposalDone, depsReady: true)),
            WorkshopArtifact(id: .specs, state: state(done: specsDone, depsReady: proposalDone)),
            WorkshopArtifact(id: .design, state: state(done: designDone, depsReady: proposalDone)),
            WorkshopArtifact(id: .tasks, state: state(done: tasksDone, depsReady: specsDone && designDone))
        ]
    }

    // MARK: - Content Reading

    /// Read the content of an artifact file for a change.
    /// Searches both `changes/` and `archive/` directories.
    public nonisolated func readArtifactContent(repoRoot: String, changeName: String, artifactID: WorkshopArtifactID) -> String? {
        let base = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)

        for subdir in ["changes", "archive"] {
            let parent = (base as NSString).appendingPathComponent(subdir)
            let changePath = (parent as NSString).appendingPathComponent(changeName)
            if let content = readArtifactFile(changePath: changePath, artifactID: artifactID) {
                return content
            }
        }
        return nil
    }

    private nonisolated func readArtifactFile(changePath: String, artifactID: WorkshopArtifactID) -> String? {
        let filePath: String
        switch artifactID {
        case .proposal:
            filePath = (changePath as NSString).appendingPathComponent("proposal.md")
        case .specs:
            let specsDir = (changePath as NSString).appendingPathComponent("specs")
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: specsDir),
                  let first = items.sorted().first(where: { $0.hasSuffix(".md") }) else { return nil }
            filePath = (specsDir as NSString).appendingPathComponent(first)
        case .design:
            filePath = (changePath as NSString).appendingPathComponent("design.md")
        case .tasks:
            filePath = (changePath as NSString).appendingPathComponent("tasks.md")
        }

        guard let data = FileManager.default.contents(atPath: filePath) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
