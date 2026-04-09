import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct ProfileSwitchTests {
    private func makeModelWithProfileStore() -> (AppModel, ProfileStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-switch-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = ProfileStore(rootDirectory: root)
        let model = AppModel(profileStore: store)
        return (model, store)
    }

    @Test func switchProfileSameIDIsNoOp() {
        let (model, _) = makeModelWithProfileStore()
        let id = model.activeProfileID
        let wsCount = model.workspaces.count

        model.switchProfile(to: id)

        #expect(model.activeProfileID == id)
        #expect(model.workspaces.count == wsCount)
    }

    @Test func switchProfileUnknownIDIsRejected() {
        let (model, _) = makeModelWithProfileStore()
        let originalID = model.activeProfileID

        model.switchProfile(to: UUID())

        #expect(model.activeProfileID == originalID)
    }

    @Test func switchProfileSavesCurrentAndHydratesTarget() throws {
        let (model, _) = makeModelWithProfileStore()

        // Setup: name a workspace in the default profile
        model.workspaces[0].name = "DefaultWS"
        model.saveWorkspaces()

        // Create and switch to a new profile
        let work = model.createProfile(named: "Work")
        model.switchProfile(to: work.id)

        #expect(model.activeProfileID == work.id)
        // New profile starts with a fresh workspace
        #expect(model.workspaces.count == 1)
        #expect(model.workspaces[0].name != "DefaultWS")

        // Name the work profile workspace
        model.workspaces[0].name = "WorkWS"
        model.saveWorkspaces()

        // Switch back to original
        let defaultProfile = try #require(model.profiles.first { $0.name == "Default" })
        model.switchProfile(to: defaultProfile.id)

        // Original state restored
        #expect(model.activeProfileID == defaultProfile.id)
        #expect(model.workspaces[0].name == "DefaultWS")
    }

    @Test func switchProfileCallsTeardownClosure() {
        let (model, _) = makeModelWithProfileStore()
        var tornDown: [UUID] = []
        model.onTeardownWorkspace = { workspace in
            tornDown.append(workspace.id)
        }

        let wsID = model.workspaces[0].id
        let other = model.createProfile(named: "Other")
        model.switchProfile(to: other.id)

        #expect(tornDown.contains(wsID))
    }

    @Test func switchProfileCallsReloadConfig() {
        let (model, _) = makeModelWithProfileStore()
        var reloadedContent: String?
        model.onReloadConfig = { content in
            reloadedContent = content
        }

        let other = model.createProfile(named: "Other")
        model.switchProfile(to: other.id)

        #expect(reloadedContent != nil)
    }

    @Test func switchProfilePreservesSidebarState() throws {
        let (model, _) = makeModelWithProfileStore()

        // Set sidebar state in default profile
        model.sidebarMode = .condensed
        model.sidebarWidth = 300
        model.saveWorkspaces()

        // Switch to new profile and back
        let other = model.createProfile(named: "Other")
        model.switchProfile(to: other.id)

        #expect(model.sidebarMode == .full) // Fresh profile defaults
        #expect(model.sidebarWidth == 260)

        let defaultProfile = try #require(model.profiles.first { $0.name == "Default" })
        model.switchProfile(to: defaultProfile.id)

        #expect(model.sidebarMode == .condensed)
        #expect(model.sidebarWidth == 300)
    }

    @Test func switchProfilePersistsMetadata() throws {
        let (model, store) = makeModelWithProfileStore()
        let other = model.createProfile(named: "Other")
        model.switchProfile(to: other.id)

        let metadata = try #require(store.loadMetadata())
        #expect(metadata.activeProfileID == other.id)
    }
}
