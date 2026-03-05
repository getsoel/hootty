import Testing
import Foundation
@testable import KlaudeCore

@Suite struct TabTests {
    @Test func defaultShellIsZsh() {
        let tab = Tab(name: "Test")
        #expect(tab.shell == "/bin/zsh")
    }

    @Test func defaultWorkingDirectoryIsHome() {
        let tab = Tab(name: "Test")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(tab.workingDirectory == home)
    }

    @Test func customInitValuesPreserved() {
        let tab = Tab(name: "Custom", shell: "/bin/bash", workingDirectory: "/tmp")
        #expect(tab.name == "Custom")
        #expect(tab.shell == "/bin/bash")
        #expect(tab.workingDirectory == "/tmp")
    }

    @Test func isRunningDefaultsToTrue() {
        let tab = Tab(name: "Test")
        #expect(tab.isRunning == true)
    }
}
