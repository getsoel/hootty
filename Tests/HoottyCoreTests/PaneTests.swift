import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct PaneTests {
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

    @Test func toggleFlagFlipsState() {
        let pane = Pane(name: "zsh")
        #expect(pane.isFlagged == false)
        pane.toggleFlag()
        #expect(pane.isFlagged == true)
        pane.toggleFlag()
        #expect(pane.isFlagged == false)
    }

    @Test func flagAndNoteAreIndependent() {
        let pane = Pane(name: "zsh")
        pane.toggleFlag()
        pane.setNote("important")
        #expect(pane.isFlagged == true)
        #expect(pane.hasNote == true)
        pane.toggleFlag()
        #expect(pane.isFlagged == false)
        #expect(pane.hasNote == true)
    }
}
