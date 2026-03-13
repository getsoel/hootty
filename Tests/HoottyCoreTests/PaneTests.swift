import Testing
import Foundation
@testable import HoottyCore

@Suite struct PaneTests {
    @Test func displayNameReturnsAbbreviatedPathWhenNoCustomName() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pane = Pane(name: "zsh", workingDirectory: home + "/Projects/myapp")
        #expect(pane.displayName == "~/Projects/myapp")
    }

    @Test func displayNameReturnsCustomNameWhenSet() {
        let pane = Pane(name: "zsh")
        pane.customName = "My Server"
        #expect(pane.displayName == "My Server")
    }

    @Test func displayNameRevertsWhenCustomNameCleared() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pane = Pane(name: "zsh", workingDirectory: home + "/Projects/myapp")
        pane.customName = "My Server"
        pane.customName = nil
        #expect(pane.displayName == "~/Projects/myapp")
    }
}
