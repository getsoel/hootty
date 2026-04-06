import Foundation
import os

public struct WorkspaceSnapshot: Codable {
    public var workspaces: [Workspace]
    public var selectedWorkspaceID: UUID?
    public var sidebarWidth: CGFloat?
    public var sidebarMode: SidebarMode?
    public var collapsedWorkspaceIDs: Set<UUID>?
    public var pinnedWorkspaceID: UUID?

    /// Legacy field for backward-compatible decoding only. Not written on new saves.
    public var sidebarVisible: Bool?

    public init(
        workspaces: [Workspace],
        selectedWorkspaceID: UUID?,
        sidebarWidth: CGFloat? = nil,
        sidebarMode: SidebarMode? = nil,
        collapsedWorkspaceIDs: Set<UUID>? = nil,
        pinnedWorkspaceID: UUID? = nil
    ) {
        self.workspaces = workspaces
        self.selectedWorkspaceID = selectedWorkspaceID
        self.sidebarWidth = sidebarWidth
        self.sidebarMode = sidebarMode
        self.collapsedWorkspaceIDs = collapsedWorkspaceIDs
        self.pinnedWorkspaceID = pinnedWorkspaceID
    }

    private enum CodingKeys: String, CodingKey {
        case workspaces, selectedWorkspaceID, sidebarWidth, sidebarMode, sidebarVisible
        case collapsedWorkspaceIDs, pinnedWorkspaceID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workspaces, forKey: .workspaces)
        try container.encodeIfPresent(selectedWorkspaceID, forKey: .selectedWorkspaceID)
        try container.encodeIfPresent(sidebarWidth, forKey: .sidebarWidth)
        try container.encodeIfPresent(sidebarMode, forKey: .sidebarMode)
        // sidebarVisible intentionally not written
        try container.encodeIfPresent(collapsedWorkspaceIDs, forKey: .collapsedWorkspaceIDs)
        try container.encodeIfPresent(pinnedWorkspaceID, forKey: .pinnedWorkspaceID)
    }
}

public final class WorkspaceStore {
    private static let logger = Logger(subsystem: "com.soel.hootty", category: "workspaces")

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #if DEBUG
            let dir = appSupport.appendingPathComponent("Hootty-Dev", isDirectory: true)
        #else
            let dir = appSupport.appendingPathComponent("Hootty", isDirectory: true)
        #endif
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

    public func deleteStorage() {
        try? FileManager.default.removeItem(at: fileURL)
        Self.logger.info("Deleted workspace storage")
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
