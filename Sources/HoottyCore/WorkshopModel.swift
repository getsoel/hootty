import Foundation

// MARK: - Data Types

public enum WorkshopArtifactID: String, CaseIterable, Sendable {
    case intent
    case requirements
    case design
    case tasks

    public var displayName: String {
        switch self {
        case .intent: "Intent"
        case .requirements: "Requirements"
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
    /// Strips leading date prefix (YYYY-MM-DD-) from archived change names.
    public static func formatName(_ name: String) -> String {
        let stripped = if name.count > 11,
                          let range = name.range(of: #"^\d{4}-\d{2}-\d{2}-"#, options: .regularExpression) {
            String(name[range.upperBound...])
        } else {
            name
        }
        return stripped.split(separator: "-")
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

    /// Relative path from repo root to the hootty stale tracking directory.
    public static let stalePath = ".hootty/stale"

    /// Workshop status per repo root.
    public private(set) var statusByRepo: [String: WorkshopRepoStatus] = [:]

    /// Claims per pane ID, keyed by UUID string. Merged across all repo roots.
    public private(set) var claimsByPaneID: [String: WorkshopClaim] = [:]

    /// Cached task groups per change name, refreshed alongside claims.
    public private(set) var taskGroupsByChange: [String: [WorkshopTaskGroup]] = [:]

    /// Artifacts marked stale (edited since last review), keyed by change name.
    public private(set) var staleArtifacts: [String: Set<WorkshopArtifactID>] = [:]

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
        let activeDir = (workshopPath as NSString).appendingPathComponent("active")
        changes.append(contentsOf: Self.scanDirectory(activeDir, isArchived: false))

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
    /// Auto-releases claims for changes no longer in `active/` (e.g., shipped/archived).
    /// Also caches task groups for any claimed changes.
    public func refreshClaims(repoRoot: String) {
        let claimsDir = (repoRoot as NSString).appendingPathComponent(Self.claimsPath)
        let fm = FileManager.default
        var repoClaims = Self.scanClaims(claimsDir)

        // Auto-release claims for changes that no longer exist in active/
        for (paneID, claim) in repoClaims where !Self.changeExistsInRepo(claim.change, repoRoot: repoRoot) {
            let path = (claimsDir as NSString).appendingPathComponent("\(paneID).yaml")
            try? fm.removeItem(atPath: path)
            repoClaims.removeValue(forKey: paneID)
        }

        // Merge: remove stale claims from this repo, add/update current ones.
        var merged = claimsByPaneID
        for (paneID, existing) in merged {
            // Remove claims whose file was deleted and change belongs to this repo
            if repoClaims[paneID] == nil, Self.changeExistsInRepo(existing.change, repoRoot: repoRoot) {
                merged.removeValue(forKey: paneID)
            }
        }
        // Also remove in-memory claims for shipped changes (file just deleted above)
        for (paneID, existing) in merged {
            if !Self.changeExistsInRepo(existing.change, repoRoot: repoRoot),
               repoClaims[paneID] == nil {
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

    /// Write a claim file for a pane and update in-memory state.
    public func writeClaim(repoRoot: String, paneID: String, change: String, taskGroup: String? = nil) {
        let claimsDir = (repoRoot as NSString).appendingPathComponent(Self.claimsPath)
        let fm = FileManager.default
        try? fm.createDirectory(atPath: claimsDir, withIntermediateDirectories: true)

        let iso = ISO8601DateFormatter()
        let now = iso.string(from: Date())
        var lines = ["change: \(change)", "claimedAt: \(now)"]
        if let taskGroup {
            lines.insert("taskGroup: \(taskGroup)", at: 1)
        }
        let content = lines.joined(separator: "\n")
        let path = (claimsDir as NSString).appendingPathComponent("\(paneID).yaml")
        try? content.write(toFile: path, atomically: true, encoding: .utf8)

        claimsByPaneID[paneID] = WorkshopClaim(change: change, taskGroup: taskGroup, claimedAt: now)
    }

    /// Remove a claim file for a pane and update in-memory state.
    public func removeClaim(repoRoot: String, paneID: String) {
        let claimsDir = (repoRoot as NSString).appendingPathComponent(Self.claimsPath)
        let path = (claimsDir as NSString).appendingPathComponent("\(paneID).yaml")
        try? FileManager.default.removeItem(atPath: path)
        claimsByPaneID.removeValue(forKey: paneID)
    }

    private nonisolated static func changeExistsInRepo(_ changeName: String, repoRoot: String) -> Bool {
        let base = (repoRoot as NSString).appendingPathComponent(directoryPath)
        let activeDir = ((base as NSString).appendingPathComponent("active") as NSString).appendingPathComponent(changeName)
        return FileManager.default.fileExists(atPath: activeDir)
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
        for subdir in ["active", "archive"] {
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
    /// DAG: intent → requirements → design → tasks (linear chain)
    /// Uses a single `contentsOfDirectory` per change to minimize syscalls.
    private nonisolated static func resolveArtifacts(changePath: String) -> [WorkshopArtifact] {
        let fm = FileManager.default
        let entries = Set((try? fm.contentsOfDirectory(atPath: changePath)) ?? [])

        let intentDone = entries.contains("intent.md")

        let reqsDone: Bool = {
            let reqsDir = (changePath as NSString).appendingPathComponent("requirements")
            guard let dirs = try? fm.contentsOfDirectory(atPath: reqsDir) else { return false }
            return dirs.contains { subdir in
                var isDir: ObjCBool = false
                let subdirPath = (reqsDir as NSString).appendingPathComponent(subdir)
                guard fm.fileExists(atPath: subdirPath, isDirectory: &isDir), isDir.boolValue else { return false }
                return fm.fileExists(atPath: (subdirPath as NSString).appendingPathComponent("req.md"))
            }
        }()

        let designDone = entries.contains("design.md")
        let tasksDone = entries.contains("tasks.md")

        func state(done: Bool, depsReady: Bool) -> WorkshopArtifactState {
            done ? .done : (depsReady ? .ready : .blocked)
        }

        return [
            WorkshopArtifact(id: .intent, state: state(done: intentDone, depsReady: true)),
            WorkshopArtifact(id: .requirements, state: state(done: reqsDone, depsReady: intentDone)),
            WorkshopArtifact(id: .design, state: state(done: designDone, depsReady: reqsDone)),
            WorkshopArtifact(id: .tasks, state: state(done: tasksDone, depsReady: designDone))
        ]
    }

    // MARK: - Requirement File Listing

    public struct RequirementFile: Identifiable, Sendable {
        public let name: String
        public let path: String
        public var id: String {
            path
        }
    }

    /// List individual requirement files for a change's requirements/ directory.
    /// Returns requirement files sorted alphabetically by subdirectory name.
    public nonisolated func requirementFiles(repoRoot: String, changeName: String) -> [RequirementFile] {
        let base = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)
        let fm = FileManager.default
        for subdir in ["active", "archive"] {
            let reqsDir = ((base as NSString).appendingPathComponent(subdir) as NSString)
                .appendingPathComponent(changeName)
                .appending("/requirements")
            guard let items = try? fm.contentsOfDirectory(atPath: reqsDir) else { continue }
            var results: [RequirementFile] = []
            for item in items.sorted() {
                guard !item.hasPrefix(".") else { continue }
                let subdirPath = (reqsDir as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: subdirPath, isDirectory: &isDir), isDir.boolValue else { continue }
                let reqPath = (subdirPath as NSString).appendingPathComponent("req.md")
                if fm.fileExists(atPath: reqPath) {
                    results.append(RequirementFile(name: WorkshopChange.formatName(item), path: reqPath))
                }
            }
            if !results.isEmpty { return results }
        }
        return []
    }

    // MARK: - Content Reading

    /// Read the content of an artifact file for a change.
    /// Searches both `changes/` and `archive/` directories.
    public nonisolated func readArtifactContent(repoRoot: String, changeName: String, artifactID: WorkshopArtifactID) -> String? {
        guard let path = artifactFilePath(repoRoot: repoRoot, changeName: changeName, artifactID: artifactID),
              let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Resolve the on-disk file path for an artifact.
    /// Searches both `changes/` and `archive/` directories.
    public nonisolated func artifactFilePath(repoRoot: String, changeName: String, artifactID: WorkshopArtifactID) -> String? {
        let base = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)

        for subdir in ["active", "archive"] {
            let changePath = ((base as NSString).appendingPathComponent(subdir) as NSString)
                .appendingPathComponent(changeName)
            if let path = resolveArtifactFilePath(changePath: changePath, artifactID: artifactID) {
                return path
            }
        }
        return nil
    }

    private nonisolated func resolveArtifactFilePath(changePath: String, artifactID: WorkshopArtifactID) -> String? {
        let fm = FileManager.default
        let path: String
        switch artifactID {
        case .intent:
            path = (changePath as NSString).appendingPathComponent("intent.md")
        case .requirements:
            let reqsDir = (changePath as NSString).appendingPathComponent("requirements")
            guard let items = try? fm.contentsOfDirectory(atPath: reqsDir),
                  let first = items.sorted().first(where: { $0.hasSuffix(".md") }) else { return nil }
            path = (reqsDir as NSString).appendingPathComponent(first)
        case .design:
            path = (changePath as NSString).appendingPathComponent("design.md")
        case .tasks:
            path = (changePath as NSString).appendingPathComponent("tasks.md")
        }
        return fm.fileExists(atPath: path) ? path : nil
    }

    // MARK: - Stale Tracking

    /// Check if an artifact has been edited since its last review.
    public func isStale(changeName: String, artifactID: WorkshopArtifactID) -> Bool {
        staleArtifacts[changeName]?.contains(artifactID) ?? false
    }

    /// Mark an artifact as stale (edited in the markdown editor).
    public func markArtifactStale(repoRoot: String, changeName: String, artifactID: WorkshopArtifactID) {
        var stale = staleArtifacts[changeName] ?? []
        guard !stale.contains(artifactID) else { return }
        stale.insert(artifactID)
        staleArtifacts[changeName] = stale
        writeStaleState(repoRoot: repoRoot, changeName: changeName, stale: stale)
    }

    /// Clear the stale flag for an artifact (after review).
    public func markArtifactReviewed(repoRoot: String, changeName: String, artifactID: WorkshopArtifactID) {
        guard var stale = staleArtifacts[changeName], stale.contains(artifactID) else { return }
        stale.remove(artifactID)
        if stale.isEmpty {
            staleArtifacts.removeValue(forKey: changeName)
        } else {
            staleArtifacts[changeName] = stale
        }
        writeStaleState(repoRoot: repoRoot, changeName: changeName, stale: stale)
    }

    /// Refresh stale state from disk for a repo.
    public func refreshStale(repoRoot: String) {
        guard let status = statusByRepo[repoRoot] else { return }
        var newStale = staleArtifacts
        for change in status.changes {
            let stale = readStaleState(repoRoot: repoRoot, changeName: change.name)
            if stale.isEmpty {
                newStale.removeValue(forKey: change.name)
            } else {
                newStale[change.name] = stale
            }
        }
        if newStale != staleArtifacts {
            staleArtifacts = newStale
        }
    }

    private nonisolated func readStaleState(repoRoot: String, changeName: String) -> Set<WorkshopArtifactID> {
        let path = ((repoRoot as NSString).appendingPathComponent(Self.stalePath) as NSString)
            .appendingPathComponent("\(changeName).yaml")
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return [] }
        let parsed = Self.parseSimpleYaml(content)
        var stale: Set<WorkshopArtifactID> = []
        for id in WorkshopArtifactID.allCases where parsed[id.rawValue] == "true" {
            stale.insert(id)
        }
        return stale
    }

    private nonisolated func writeStaleState(repoRoot: String, changeName: String, stale: Set<WorkshopArtifactID>) {
        let staleDir = (repoRoot as NSString).appendingPathComponent(Self.stalePath)
        let fm = FileManager.default
        try? fm.createDirectory(atPath: staleDir, withIntermediateDirectories: true)

        let path = (staleDir as NSString).appendingPathComponent("\(changeName).yaml")
        if stale.isEmpty {
            try? fm.removeItem(atPath: path)
            return
        }
        let lines = WorkshopArtifactID.allCases
            .filter { stale.contains($0) }
            .map { "\($0.rawValue): true" }
        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - File Path Resolution

    /// Resolve a file path back to its artifact context (repo root, change name, artifact ID).
    public nonisolated func resolveArtifactContext(filePath: String) -> (repoRoot: String, changeName: String, artifactID: WorkshopArtifactID)? {
        // Find "workshop/" boundary to extract repo root
        guard let workshopRange = filePath.range(of: "/workshop/") else { return nil }
        let repoRoot = String(filePath[filePath.startIndex ..< workshopRange.lowerBound])

        // Path after "workshop/" — e.g. "active/add-auth/intent.md"
        let relative = String(filePath[workshopRange.upperBound...])
        let components = relative.split(separator: "/").map(String.init)

        // Expect: ["active"|"archive", changeName, ...]
        guard components.count >= 3,
              components[0] == "active" || components[0] == "archive" else { return nil }
        let changeName = components[1]
        let artifactFile = components[2]

        let artifactID: WorkshopArtifactID
        switch artifactFile {
        case "intent.md": artifactID = .intent
        case "design.md": artifactID = .design
        case "tasks.md": artifactID = .tasks
        case "requirements": artifactID = .requirements
        default: return nil
        }

        return (repoRoot: repoRoot, changeName: changeName, artifactID: artifactID)
    }
}
