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

    // MARK: - Sidebar Filter Matching

    @Test func matchesEmptyFiltersReturnsTrue() {
        let pane = Pane(name: "zsh")
        #expect(pane.matches([]) == true)
    }

    @Test func matchesThinkingFilter() {
        let pane = Pane(name: "zsh")
        #expect(pane.matches([.thinking]) == false)
        pane.isThinking = true
        #expect(pane.matches([.thinking]) == true)
    }

    @Test func matchesFlaggedFilter() {
        let pane = Pane(name: "zsh")
        #expect(pane.matches([.flagged]) == false)
        pane.isFlagged = true
        #expect(pane.matches([.flagged]) == true)
    }

    @Test func matchesDoneFilter() {
        let pane = Pane(name: "zsh")
        #expect(pane.matches([.done]) == false)
        pane.attentionKind = .done
        #expect(pane.matches([.done]) == true)
    }

    @Test func matchesBellFilter() {
        let pane = Pane(name: "zsh")
        #expect(pane.matches([.bell]) == false)
        pane.attentionKind = .bell
        #expect(pane.matches([.bell]) == true)
    }

    @Test func matchesMultipleFiltersUsesORLogic() {
        let pane = Pane(name: "zsh")
        pane.isThinking = true
        #expect(pane.matches([.thinking, .flagged]) == true)
        #expect(pane.matches([.flagged, .done]) == false)
    }

    @Test func matchesWrongFilterReturnsFalse() {
        let pane = Pane(name: "zsh")
        pane.attentionKind = .bell
        #expect(pane.matches([.done]) == false)
        #expect(pane.matches([.thinking]) == false)
    }
}
