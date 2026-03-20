import Foundation

// MARK: - Data Types

public enum OpsxArtifactID: String, CaseIterable, Sendable {
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

public enum OpsxArtifactState: String, Sendable, Equatable {
    case blocked
    case ready
    case done
}

public struct OpsxArtifact: Identifiable, Sendable, Equatable {
    public let id: OpsxArtifactID
    public let state: OpsxArtifactState

    public var displayName: String {
        id.displayName
    }

    public init(id: OpsxArtifactID, state: OpsxArtifactState) {
        self.id = id
        self.state = state
    }
}

public struct OpsxChange: Identifiable, Sendable, Equatable {
    public let name: String
    public let displayName: String
    public let artifacts: [OpsxArtifact]
    public let isArchived: Bool

    public var id: String {
        name
    }

    public init(name: String, artifacts: [OpsxArtifact], isArchived: Bool = false) {
        self.name = name
        self.displayName = name.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        self.artifacts = artifacts
        self.isArchived = isArchived
    }
}

public struct OpsxRepoStatus: Sendable, Equatable {
    public let repoRoot: String
    public let changes: [OpsxChange]
    public let isInitialized: Bool

    public init(repoRoot: String, changes: [OpsxChange], isInitialized: Bool) {
        self.repoRoot = repoRoot
        self.changes = changes
        self.isInitialized = isInitialized
    }
}

// MARK: - Model

@MainActor
@Observable
public final class OpsxModel {
    /// Relative path from repo root to the openspec directory.
    public static let directoryPath = "openspec"

    /// OPSX status per repo root.
    public private(set) var statusByRepo: [String: OpsxRepoStatus] = [:]

    public init() {}

    /// Check whether an openspec directory exists at the given repo root.
    public nonisolated static func hasOpenSpec(repoRoot: String) -> Bool {
        var isDir: ObjCBool = false
        let path = (repoRoot as NSString).appendingPathComponent(directoryPath)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Get status for a specific repo root.
    public func status(for repoRoot: String) -> OpsxRepoStatus? {
        statusByRepo[repoRoot]
    }

    /// Remove status for a repo root (cleanup when no panes remain).
    public func removeStatus(for repoRoot: String) {
        statusByRepo.removeValue(forKey: repoRoot)
    }

    // MARK: - Refresh

    /// Refresh OPSX state by scanning the filesystem.
    /// Resolves artifact states from file existence using the hardcoded spec-driven schema.
    /// Only updates `statusByRepo` if state actually changed (avoids spurious re-renders).
    public func refresh(repoRoot: String) {
        let opsxPath = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)

        guard FileManager.default.fileExists(atPath: opsxPath) else {
            let empty = OpsxRepoStatus(repoRoot: repoRoot, changes: [], isInitialized: false)
            if statusByRepo[repoRoot] != empty {
                statusByRepo[repoRoot] = empty
            }
            return
        }

        var changes: [OpsxChange] = []
        let changesDir = (opsxPath as NSString).appendingPathComponent("changes")
        changes.append(contentsOf: Self.scanDirectory(changesDir, isArchived: false))

        let archiveDir = (opsxPath as NSString).appendingPathComponent("archive")
        changes.append(contentsOf: Self.scanDirectory(archiveDir, isArchived: true))

        let newStatus = OpsxRepoStatus(repoRoot: repoRoot, changes: changes, isInitialized: true)
        if statusByRepo[repoRoot] != newStatus {
            statusByRepo[repoRoot] = newStatus
        }
    }

    // MARK: - Private Helpers

    /// Scan a directory for change subdirectories, returning OpsxChange for each.
    private nonisolated static func scanDirectory(_ dirPath: String, isArchived: Bool) -> [OpsxChange] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dirPath) else { return [] }

        return items.sorted().compactMap { item -> OpsxChange? in
            guard !item.hasPrefix(".") else { return nil }
            let changePath = (dirPath as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: changePath, isDirectory: &isDir), isDir.boolValue else { return nil }
            let artifacts = resolveArtifacts(changePath: changePath)
            return OpsxChange(name: item, artifacts: artifacts, isArchived: isArchived)
        }
    }

    // MARK: - Artifact Resolution (spec-driven schema, hardcoded)

    /// Resolve artifact states from filesystem for the spec-driven schema.
    /// DAG: proposal → specs → tasks, proposal → design → tasks
    /// Uses a single `contentsOfDirectory` per change to minimize syscalls.
    private nonisolated static func resolveArtifacts(changePath: String) -> [OpsxArtifact] {
        let fm = FileManager.default
        let entries = Set((try? fm.contentsOfDirectory(atPath: changePath)) ?? [])

        let proposalDone = entries.contains("proposal.md")

        let specsDone: Bool = {
            let specsDir = (changePath as NSString).appendingPathComponent("specs")
            guard let specItems = try? fm.contentsOfDirectory(atPath: specsDir) else { return false }
            return specItems.contains { $0.hasSuffix(".md") }
        }()

        let designDone = entries.contains("design.md")
        let tasksDone = entries.contains("tasks.md")

        func state(done: Bool, depsReady: Bool) -> OpsxArtifactState {
            done ? .done : (depsReady ? .ready : .blocked)
        }

        return [
            OpsxArtifact(id: .proposal, state: state(done: proposalDone, depsReady: true)),
            OpsxArtifact(id: .specs, state: state(done: specsDone, depsReady: proposalDone)),
            OpsxArtifact(id: .design, state: state(done: designDone, depsReady: proposalDone)),
            OpsxArtifact(id: .tasks, state: state(done: tasksDone, depsReady: specsDone && designDone))
        ]
    }

    // MARK: - Content Reading

    /// Read the content of an artifact file for a change.
    /// Searches both `changes/` and `archive/` directories.
    public nonisolated func readArtifactContent(repoRoot: String, changeName: String, artifactID: OpsxArtifactID) -> String? {
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

    private nonisolated func readArtifactFile(changePath: String, artifactID: OpsxArtifactID) -> String? {
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
