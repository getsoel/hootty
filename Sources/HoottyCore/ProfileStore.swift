import Foundation
import os

/// Manages profile metadata persistence and per-profile directory layout.
///
/// Directory structure:
/// ```
/// <rootDirectory>/
///   profiles.json              -- ProfilesMetadata
///   profiles/<uuid>/
///     config                   -- ConfigFile key-value store
///     workspaces.json          -- WorkspaceSnapshot
/// ```
public final class ProfileStore {
    private static let logger = Logger(subsystem: "com.soel.hootty", category: "profiles")

    public let rootDirectory: URL
    private let metadataURL: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.metadataURL = rootDirectory.appendingPathComponent("profiles.json")
    }

    public convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #if DEBUG
            let dir = appSupport.appendingPathComponent("Hootty-Dev", isDirectory: true)
        #else
            let dir = appSupport.appendingPathComponent("Hootty", isDirectory: true)
        #endif
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(rootDirectory: dir)
    }

    // MARK: - Metadata I/O

    public func loadMetadata() -> ProfilesMetadata? {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            Self.logger.info("No profiles.json found")
            return nil
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(ProfilesMetadata.self, from: data)
            Self.logger.info("Loaded \(metadata.profiles.count) profile(s)")
            return metadata
        } catch {
            Self.logger.error("Failed to load profiles.json: \(error.localizedDescription)")
            return nil
        }
    }

    public func saveMetadata(_ metadata: ProfilesMetadata) {
        do {
            try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(metadata)
            try data.write(to: metadataURL, options: .atomic)
            Self.logger.debug("Saved profiles metadata (\(metadata.profiles.count) profile(s))")
        } catch {
            Self.logger.error("Failed to save profiles.json: \(error.localizedDescription)")
        }
    }

    // MARK: - Per-profile directories and factories

    public func profileDirectory(for id: UUID) -> URL {
        rootDirectory
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    @MainActor
    public func workspaceStore(for id: UUID) -> WorkspaceStore {
        WorkspaceStore(fileURL: profileDirectory(for: id).appendingPathComponent("workspaces.json"))
    }

    @MainActor
    public func configFile(for id: UUID) -> ConfigFile {
        ConfigFile(fileURL: profileDirectory(for: id).appendingPathComponent("config"))
    }

    public func createProfileDirectory(id: UUID, seedingDefaultConfig: Bool = true) {
        let dir = profileDirectory(for: id)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if seedingDefaultConfig {
                let configURL = dir.appendingPathComponent("config")
                if !FileManager.default.fileExists(atPath: configURL.path) {
                    try ConfigFile.defaultConfigContent().write(to: configURL, atomically: true, encoding: .utf8)
                }
            }
            Self.logger.info("Created profile directory: \(dir.path)")
        } catch {
            Self.logger.error("Failed to create profile directory: \(error.localizedDescription)")
        }
    }

    public func deleteProfileDirectory(id: UUID) {
        let dir = profileDirectory(for: id)
        do {
            try FileManager.default.removeItem(at: dir)
            Self.logger.info("Deleted profile directory: \(dir.path)")
        } catch {
            Self.logger.error("Failed to delete profile directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Migration

    /// Migrates from the legacy flat layout (root `config` + `workspaces.json`)
    /// into a `profiles/<uuid>/` directory. Idempotent — no-op if `profiles.json` exists.
    public func migrateIfNeeded() {
        let fm = FileManager.default

        // Already migrated — no-op
        if fm.fileExists(atPath: metadataURL.path) {
            Self.logger.debug("profiles.json exists, skipping migration")
            return
        }

        let profilesDir = rootDirectory.appendingPathComponent("profiles", isDirectory: true)

        // Partial-migration recovery: profiles/ exists but no profiles.json
        if fm.fileExists(atPath: profilesDir.path) {
            Self.logger.error("Partial migration detected: profiles/ directory exists but no profiles.json. Refusing to overwrite.")
            return
        }

        let legacyConfig = rootDirectory.appendingPathComponent("config")
        let legacyWorkspaces = rootDirectory.appendingPathComponent("workspaces.json")
        let hasLegacyConfig = fm.fileExists(atPath: legacyConfig.path)
        let hasLegacyWorkspaces = fm.fileExists(atPath: legacyWorkspaces.path)

        let profileID = UUID()
        let profile = Profile(id: profileID, name: "Default")

        if hasLegacyConfig || hasLegacyWorkspaces {
            // Happy path: legacy files exist — move them into the new profile directory
            Self.logger.info("Migrating legacy layout to profiles/\(profileID.uuidString)/")

            let dir = profileDirectory(for: profileID)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                Self.logger.error("Failed to create profile directory during migration: \(error.localizedDescription)")
                return
            }

            // Move files before writing profiles.json (crash-safe ordering)
            if hasLegacyConfig {
                let dest = dir.appendingPathComponent("config")
                do {
                    try fm.moveItem(at: legacyConfig, to: dest)
                } catch {
                    Self.logger.error("Failed to move config during migration: \(error.localizedDescription)")
                    return
                }
            }

            if hasLegacyWorkspaces {
                let dest = dir.appendingPathComponent("workspaces.json")
                do {
                    try fm.moveItem(at: legacyWorkspaces, to: dest)
                } catch {
                    Self.logger.error("Failed to move workspaces.json during migration: \(error.localizedDescription)")
                    return
                }
            }

            let metadata = ProfilesMetadata(activeProfileID: profileID, profiles: [profile])
            saveMetadata(metadata)
            Self.logger.info("Migration complete")
        } else {
            // No legacy files — fresh install, write bare profiles.json
            Self.logger.info("No legacy files found, creating fresh profiles.json with Default profile")
            let metadata = ProfilesMetadata(activeProfileID: profileID, profiles: [profile])
            saveMetadata(metadata)
            // Directory created lazily on first workspace save
        }
    }
}
