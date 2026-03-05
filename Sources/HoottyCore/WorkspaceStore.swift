import Foundation
import os

public struct WorkspaceSnapshot: Codable {
    public var workspaces: [Workspace]
    public var selectedWorkspaceID: UUID?

    public init(workspaces: [Workspace], selectedWorkspaceID: UUID?) {
        self.workspaces = workspaces
        self.selectedWorkspaceID = selectedWorkspaceID
    }
}

public final class WorkspaceStore {
    private static let logger = Logger(subsystem: "com.soel.hootty", category: "workspaces")

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Hootty", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("workspaces.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> WorkspaceSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Self.logger.info("No workspaces file found")
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
            guard !snapshot.workspaces.isEmpty else {
                Self.logger.info("Workspaces file was empty")
                return nil
            }
            Self.logger.info("Loaded \(snapshot.workspaces.count) workspace(s)")
            return snapshot
        } catch {
            Self.logger.error("Failed to load workspaces: \(error.localizedDescription)")
            return nil
        }
    }

    public func save(_ snapshot: WorkspaceSnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            Self.logger.debug("Saved \(snapshot.workspaces.count) workspace(s)")
        } catch {
            Self.logger.error("Failed to save workspaces: \(error.localizedDescription)")
        }
    }
}
