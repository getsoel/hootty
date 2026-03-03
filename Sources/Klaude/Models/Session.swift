import Foundation

@Observable
final class Session: Identifiable {
    let id = UUID()
    var name: String
    let ptySession: PTYSession

    init(name: String) {
        self.name = name
        self.ptySession = PTYSession()
    }

    deinit {
        ptySession.stop()
    }
}
