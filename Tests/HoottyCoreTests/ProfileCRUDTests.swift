import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct ProfileCRUDTests {
    private func makeModelWithProfileStore() -> (AppModel, ProfileStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-crud-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = ProfileStore(rootDirectory: root)
        let model = AppModel(profileStore: store)
        return (model, store)
    }

    @Test func createProfileAddsToList() {
        let (model, _) = makeModelWithProfileStore()
        let initialCount = model.profiles.count
        let profile = model.createProfile(named: "Work")

        #expect(model.profiles.count == initialCount + 1)
        #expect(profile.name == "Work")
        #expect(model.profiles.contains(where: { $0.id == profile.id }))
    }

    @Test func createProfileDisambiguatesDuplicateNames() {
        let (model, _) = makeModelWithProfileStore()
        let p1 = model.createProfile(named: "Work")
        let p2 = model.createProfile(named: "Work")

        #expect(p1.name == "Work")
        #expect(p2.name == "Work 2")
    }

    @Test func createProfileDoesNotActivate() {
        let (model, _) = makeModelWithProfileStore()
        let originalID = model.activeProfileID
        _ = model.createProfile(named: "Other")

        #expect(model.activeProfileID == originalID)
    }

    @Test func renameProfileUpdatesName() {
        let (model, _) = makeModelWithProfileStore()
        let profileID = model.profiles[0].id
        model.renameProfile(id: profileID, to: "Personal")

        #expect(model.profiles[0].name == "Personal")
    }

    @Test func renameProfileRejectsEmptyName() {
        let (model, _) = makeModelWithProfileStore()
        let originalName = model.profiles[0].name
        model.renameProfile(id: model.profiles[0].id, to: "   ")

        #expect(model.profiles[0].name == originalName)
    }

    @Test func deleteProfileRejectsLastProfile() {
        let (model, _) = makeModelWithProfileStore()
        #expect(model.profiles.count == 1)

        let id = model.profiles[0].id
        model.deleteProfile(id: id)

        // Should still have 1 profile
        #expect(model.profiles.count == 1)
    }

    @Test func deleteNonActiveProfile() {
        let (model, _) = makeModelWithProfileStore()
        let activeID = model.activeProfileID
        let other = model.createProfile(named: "ToDelete")

        model.deleteProfile(id: other.id)

        #expect(model.profiles.count == 1)
        #expect(model.activeProfileID == activeID)
        #expect(!model.profiles.contains(where: { $0.id == other.id }))
    }

    @Test func deleteActiveProfileSwitchesFirst() {
        let (model, _) = makeModelWithProfileStore()
        let originalID = model.activeProfileID
        let other = model.createProfile(named: "Survivor")

        model.deleteProfile(id: originalID)

        #expect(model.profiles.count == 1)
        #expect(model.activeProfileID == other.id)
    }

    @Test func metadataPersistedAfterCRUD() throws {
        let (model, store) = makeModelWithProfileStore()
        _ = model.createProfile(named: "Persisted")

        let metadata = try #require(store.loadMetadata())
        #expect(metadata.profiles.count == model.profiles.count)
    }
}
