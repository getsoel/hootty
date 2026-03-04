import Testing
import Foundation
@testable import KlaudeCore

@Suite struct AppModelTests {
    @Test func initCreatesOneDefaultSession() {
        let model = AppModel()
        #expect(model.sessions.count == 1)
    }

    @Test func addSessionIncrementsAndAppends() {
        let model = AppModel()
        let second = model.addSession()
        #expect(model.sessions.count == 2)
        #expect(second.name == "Session 2")
    }

    @Test func addSessionNamesSequentially() {
        let model = AppModel()
        _ = model.addSession()
        let third = model.addSession()
        #expect(third.name == "Session 3")
    }

    @Test func removeSessionRemovesCorrectSession() {
        let model = AppModel()
        let second = model.addSession()
        let secondID = second.id
        model.removeSession(at: IndexSet(integer: 0))
        #expect(model.sessions.count == 1)
        #expect(model.sessions.first?.id == secondID)
    }

    @Test func removeSessionByIDRemovesCorrectSession() {
        let model = AppModel()
        let firstID = model.sessions.first!.id
        let second = model.addSession()
        model.removeSession(id: firstID)
        #expect(model.sessions.count == 1)
        #expect(model.sessions.first?.id == second.id)
    }

    @Test func removeSessionByIDNoOpForUnknownID() {
        let model = AppModel()
        model.removeSession(id: UUID())
        #expect(model.sessions.count == 1)
    }

    @Test func toggleSidebarFlipsVisibility() {
        let model = AppModel()
        #expect(model.sidebarVisible == true)
        model.toggleSidebar()
        #expect(model.sidebarVisible == false)
        model.toggleSidebar()
        #expect(model.sidebarVisible == true)
    }
}
