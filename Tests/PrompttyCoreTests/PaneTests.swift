import Testing
import Foundation
@testable import PrompttyCore

@Suite struct PaneTests {
    @Test func defaultShellIsZsh() {
        let pane = Pane(name: "Test")
        #expect(pane.shell == "/bin/zsh")
    }

    @Test func defaultWorkingDirectoryIsHome() {
        let pane = Pane(name: "Test")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(pane.workingDirectory == home)
    }

    @Test func customInitValuesPreserved() {
        let pane = Pane(name: "Custom", shell: "/bin/bash", workingDirectory: "/tmp")
        #expect(pane.name == "Custom")
        #expect(pane.shell == "/bin/bash")
        #expect(pane.workingDirectory == "/tmp")
    }

    @Test func isRunningDefaultsToTrue() {
        let pane = Pane(name: "Test")
        #expect(pane.isRunning == true)
    }

    @Test func needsAttentionDefaultsToFalse() {
        let pane = Pane(name: "Test")
        #expect(pane.needsAttention == false)
    }
}
