import Foundation
@testable import HoottyCore

/// Shared test helpers to reduce duplication across test suites.
enum TestHelpers {
    /// Create a unique temporary directory for test config files.
    static func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
    }

    /// Create a unique temporary config file URL.
    static func tempFileURL() -> URL {
        tempDir().appendingPathComponent("config")
    }

    /// Create an isolated ProfileStore with a temp root directory.
    static func tempProfileStore() -> ProfileStore {
        ProfileStore(rootDirectory: tempDir())
    }

    /// Create an AppModel with isolated temp storage (no disk pollution).
    @MainActor
    static func makeModel() -> AppModel {
        let wsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        let cfgURL = tempFileURL()
        return AppModel(
            profileStore: tempProfileStore(),
            workspaceStore: WorkspaceStore(fileURL: wsURL),
            configFile: ConfigFile(fileURL: cfgURL)
        )
    }

    /// Create an AppModel and return the workspace store URL for reload tests.
    @MainActor
    static func makeModelWithURL() -> (AppModel, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        let cfgURL = tempFileURL()
        return (AppModel(
            profileStore: tempProfileStore(),
            workspaceStore: WorkspaceStore(fileURL: url),
            configFile: ConfigFile(fileURL: cfgURL)
        ), url)
    }

    /// Reload an AppModel from a previously saved workspace store URL.
    @MainActor
    static func reloadModel(from url: URL) -> AppModel {
        AppModel(
            profileStore: tempProfileStore(),
            workspaceStore: WorkspaceStore(fileURL: url),
            configFile: ConfigFile(fileURL: tempFileURL())
        )
    }
}
