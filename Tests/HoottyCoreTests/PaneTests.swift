import Testing
import Foundation
@testable import HoottyCore

@Suite struct PaneTests {
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
}
