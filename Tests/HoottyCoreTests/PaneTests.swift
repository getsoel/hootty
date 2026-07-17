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

    // MARK: - Resumable Session Persistence

    @Test func resumableRoundTripsWithConfigDir() throws {
        let pane = Pane(name: "zsh", resumable: ResumableSession(sessionID: "abc-123", configDir: "/Users/x/.claude-soel"))
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(Pane.self, from: data)
        #expect(decoded.resumable == ResumableSession(sessionID: "abc-123", configDir: "/Users/x/.claude-soel"))
    }

    @Test func resumableRoundTripsWithoutConfigDir() throws {
        let pane = Pane(name: "zsh", resumable: ResumableSession(sessionID: "abc-123"))
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(Pane.self, from: data)
        #expect(decoded.resumable?.sessionID == "abc-123")
        #expect(decoded.resumable?.configDir == nil)
    }

    @Test func resumeCommandWithConfigDirPrefixesEnvAndSkipsPermissions() {
        let s = ResumableSession(sessionID: "e73be225-271b-435a-800e-59065c059065", configDir: "/Users/x/.claude-soel")
        #expect(s.resumeCommand() == "CLAUDE_CONFIG_DIR='/Users/x/.claude-soel' claude --dangerously-skip-permissions --resume e73be225-271b-435a-800e-59065c059065")
    }

    @Test func resumeCommandWithoutConfigDirOmitsEnvPrefix() {
        let s = ResumableSession(sessionID: "abc-123")
        #expect(s.resumeCommand() == "claude --dangerously-skip-permissions --resume abc-123")
    }

    @Test func resumeCommandCanOmitDangerousFlag() {
        let s = ResumableSession(sessionID: "abc-123")
        #expect(s.resumeCommand(dangerouslySkipPermissions: false) == "claude --resume abc-123")
    }

    @Test func resumeCommandSingleQuotesConfigDirWithSpaces() {
        let s = ResumableSession(sessionID: "abc-123", configDir: "/Users/x/Config Dir")
        #expect(s.resumeCommand().hasPrefix("CLAUDE_CONFIG_DIR='/Users/x/Config Dir' "))
    }

    @Test func legacyPaneWithoutResumableDecodesToNil() throws {
        // Fixture: a Pane JSON blob from before the resumable field existed.
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "name": "Test Pane",
            "shell": "/bin/zsh",
            "workingDirectory": "/tmp/project"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let pane = try JSONDecoder().decode(Pane.self, from: data)
        #expect(pane.resumable == nil)
    }
}
