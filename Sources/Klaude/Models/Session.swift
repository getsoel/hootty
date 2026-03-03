import Foundation

@Observable
final class Session: Identifiable {
    let id = UUID()
    var name: String
    var isRunning = true
    var shell: String
    var workingDirectory: String

    init(name: String, shell: String = "/bin/zsh", workingDirectory: String? = nil) {
        self.name = name
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
    }
}
