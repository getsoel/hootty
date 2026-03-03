import Foundation

@Observable
final class AppModel {
    let themeManager = ThemeManager()
    var sessions: [Session] = []
    private var sessionCounter = 0

    init() {
        addSession()
    }

    @discardableResult
    func addSession() -> Session {
        sessionCounter += 1
        let session = Session(name: "Session \(sessionCounter)")
        sessions.append(session)
        return session
    }

    func removeSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
    }
}
