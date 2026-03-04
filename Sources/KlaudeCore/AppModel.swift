import Foundation

@Observable
public final class AppModel {
    public let themeManager = ThemeManager()
    public var sessions: [Session] = []
    public var sidebarVisible: Bool = true
    private var sessionCounter = 0

    public init() {
        addSession()
    }

    @discardableResult
    public func addSession() -> Session {
        sessionCounter += 1
        let session = Session(name: "Session \(sessionCounter)")
        sessions.append(session)
        return session
    }

    public func removeSession(at offsets: IndexSet) {
        for index in offsets.reversed() {
            sessions.remove(at: index)
        }
    }

    public func removeSession(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    public func toggleSidebar() {
        sidebarVisible.toggle()
    }
}
