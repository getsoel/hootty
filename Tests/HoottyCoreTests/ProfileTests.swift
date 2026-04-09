import Foundation
import Testing
@testable import HoottyCore

struct ProfileCodableTests {
    @Test func profileRoundTrip() throws {
        let profile = Profile(name: "Work")
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded == profile)
        #expect(decoded.id == profile.id)
        #expect(decoded.name == "Work")
    }

    @Test func profilesMetadataRoundTrip() throws {
        let p1 = Profile(name: "Default")
        let p2 = Profile(name: "Personal")
        let metadata = ProfilesMetadata(activeProfileID: p1.id, profiles: [p1, p2])

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ProfilesMetadata.self, from: data)
        #expect(decoded == metadata)
        #expect(decoded.activeProfileID == p1.id)
        #expect(decoded.profiles.count == 2)
        #expect(decoded.profiles[0].name == "Default")
        #expect(decoded.profiles[1].name == "Personal")
    }

    @Test func profileEquality() {
        let id = UUID()
        let a = Profile(id: id, name: "Work")
        let b = Profile(id: id, name: "Work")
        #expect(a == b)

        let c = Profile(id: id, name: "Personal")
        #expect(a != c)
    }
}
