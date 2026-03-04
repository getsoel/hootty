import Testing
import Foundation
@testable import KlaudeCore

@Suite struct SessionTests {
    @Test func defaultShellIsZsh() {
        let session = Session(name: "Test")
        #expect(session.shell == "/bin/zsh")
    }

    @Test func defaultWorkingDirectoryIsHome() {
        let session = Session(name: "Test")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(session.workingDirectory == home)
    }

    @Test func customInitValuesPreserved() {
        let session = Session(name: "Custom", shell: "/bin/bash", workingDirectory: "/tmp")
        #expect(session.name == "Custom")
        #expect(session.shell == "/bin/bash")
        #expect(session.workingDirectory == "/tmp")
    }

    @Test func isRunningDefaultsToTrue() {
        let session = Session(name: "Test")
        #expect(session.isRunning == true)
    }
}
