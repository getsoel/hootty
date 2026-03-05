import Testing
import Foundation
@testable import HoottyCore

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

    @Test func displayNameReturnsNameWhenNoCustomName() {
        let pane = Pane(name: "zsh")
        #expect(pane.displayName == "zsh")
    }

    @Test func displayNameReturnsCustomNameWhenSet() {
        let pane = Pane(name: "zsh")
        pane.customName = "My Server"
        #expect(pane.displayName == "My Server")
    }

    @Test func displayNameRevertsWhenCustomNameCleared() {
        let pane = Pane(name: "zsh")
        pane.customName = "My Server"
        pane.customName = nil
        #expect(pane.displayName == "zsh")
    }

    @Test func codableRoundTripWithoutCustomName() throws {
        let pane = Pane(name: "zsh", shell: "/bin/zsh", workingDirectory: "/tmp")
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(Pane.self, from: data)
        #expect(decoded.name == "zsh")
        #expect(decoded.customName == nil)
        #expect(decoded.displayName == "zsh")
    }

    @Test func codableRoundTripWithCustomName() throws {
        let pane = Pane(name: "zsh", customName: "My Pane", shell: "/bin/zsh", workingDirectory: "/tmp")
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(Pane.self, from: data)
        #expect(decoded.customName == "My Pane")
        #expect(decoded.displayName == "My Pane")
        #expect(decoded.name == "zsh")
    }
}
