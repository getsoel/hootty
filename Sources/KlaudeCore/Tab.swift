import Foundation

@Observable
public final class Tab: Identifiable {
    public let id = UUID()
    public var name: String
    public var isRunning = true
    public var shell: String
    public var workingDirectory: String

    public init(name: String, shell: String = "/bin/zsh", workingDirectory: String? = nil) {
        self.name = name
        self.shell = shell
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
    }
}
