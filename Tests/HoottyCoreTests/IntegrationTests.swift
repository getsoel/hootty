import Foundation
import Testing
@testable import HoottyCore

// MARK: - Helpers

@MainActor
private func makeModel() -> (AppModel, URL) {
    TestHelpers.makeModelWithURL()
}

@MainActor
private func reloadModel(from url: URL) -> AppModel {
    TestHelpers.reloadModel(from: url)
}

// MARK: - Suite A: Workspace Lifecycle

@MainActor
struct WorkspaceLifecycleIntegration {
    @Test func createSplitRenamePersistRestore() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        // Split horizontally from initial pane, then vertically from the new pane
        let pane1 = ws.allPanes[0]
        pane1.customName = "Editor"
        let pane2 = try #require(ws.splitFocusedPane(direction: .horizontal))
        pane2.customName = "Shell"
        let pane3 = try #require(ws.splitFocusedPane(direction: .vertical))
        pane3.customName = "Logs"

        #expect(ws.allPanes.count == 3)

        ws.name = "Dev"
        ws.focusPane(id: pane1.id)
        model.saveWorkspaces()

        // Reload
        let restored = reloadModel(from: url)
        let rws = restored.workspaces[0]
        #expect(rws.name == "Dev")
        #expect(rws.allPanes.count == 3)
        #expect(rws.focusedPaneID == pane1.id)

        let names = rws.allPanes.map(\.customName)
        #expect(names.contains("Editor"))
        #expect(names.contains("Shell"))
        #expect(names.contains("Logs"))
    }

    @Test func workingDirectoryAndShellPreservedThroughPersistence() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]
        let pane1 = ws.allPanes[0]
        pane1.shell = "/bin/bash"
        pane1.workingDirectory = "/tmp/project"

        // Split inherits shell + workingDirectory from focused pane
        ws.focusPane(id: pane1.id)
        let pane2 = try #require(ws.splitFocusedPane(direction: .horizontal))

        #expect(pane2.shell == "/bin/bash")
        #expect(pane2.workingDirectory == "/tmp/project")

        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        let rPanes = restored.workspaces[0].allPanes
        for p in rPanes {
            #expect(p.shell == "/bin/bash")
            #expect(p.workingDirectory == "/tmp/project")
        }
    }

    @Test func claudeSessionIDRoundTrip() {
        let (model, url) = makeModel()
        let pane = model.workspaces[0].allPanes[0]
        pane.claudeSessionID = "session-abc-123"
        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        #expect(restored.workspaces[0].allPanes[0].claudeSessionID == "session-abc-123")
    }
}

// MARK: - Suite B: Multi-Workspace Management

@MainActor
struct MultiWorkspaceIntegration {
    @Test func createReorderDeletePersistRestore() {
        let (model, url) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()
        let ws3 = model.addWorkspace()
        model.selectedWorkspaceID = ws2.id

        // Move ws3 to front
        model.moveWorkspace(id: ws3.id, toIndex: 0)
        #expect(model.workspaces.map(\.id) == [ws3.id, ws1.id, ws2.id])

        // Delete ws1
        model.removeWorkspace(id: ws1.id)
        #expect(model.workspaces.map(\.id) == [ws3.id, ws2.id])
        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        #expect(restored.workspaces.count == 2)
        #expect(restored.workspaces.map(\.id) == [ws3.id, ws2.id])
        #expect(restored.selectedWorkspaceID == ws2.id)
    }

    @Test func selectedWorkspaceAfterDeletion() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        _ = model.addWorkspace()
        model.selectedWorkspaceID = ws1.id

        model.removeWorkspace(id: ws1.id)
        // removeWorkspace doesn't auto-select — selectedWorkspaceID still points to deleted ID
        #expect(model.selectedWorkspace == nil)
    }

    @Test func findPaneAcrossWorkspaces() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()
        let ws3 = model.addWorkspace()

        // Split panes in ws1 and ws3
        ws1.splitFocusedPane(direction: .horizontal)
        ws3.splitFocusedPane(direction: .vertical)

        // Find pane from each workspace
        let p1 = ws1.allPanes[0]
        let p2 = ws2.allPanes[0]
        let p3 = ws3.allPanes[1]

        let r1 = model.findPane(id: p1.id)
        #expect(r1?.0.id == ws1.id)
        #expect(r1?.1.id == p1.id)

        let r2 = model.findPane(id: p2.id)
        #expect(r2?.0.id == ws2.id)
        #expect(r2?.1.id == p2.id)

        let r3 = model.findPane(id: p3.id)
        #expect(r3?.0.id == ws3.id)
        #expect(r3?.1.id == p3.id)

        // Unknown ID returns nil
        #expect(model.findPane(id: UUID()) == nil)
    }

    @Test func sidebarStatePersistsAlongsideWorkspaces() {
        let (model, url) = makeModel()
        model.toggleSidebar() // now false
        model.sidebarWidth = 300
        _ = model.addWorkspace()
        let ws3 = model.addWorkspace()
        model.moveWorkspace(id: ws3.id, toIndex: 0)
        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        #expect(restored.sidebarVisible == false)
        #expect(restored.sidebarWidth == 300)
        #expect(restored.workspaces.count == 3)
        #expect(restored.workspaces[0].id == ws3.id)
    }
}

// MARK: - Suite C: Complex Split Tree Operations

@MainActor
struct SplitTreeIntegration {
    @Test func deepNestedSplitPersistRestore() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        // Start: single pane (P1). Build asymmetric 4-pane tree:
        // H split → left has P1, right gets V split → top P2, bottom gets H split → P3, P4
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal)) // P1 | P2, focus on P2
        let p3 = try #require(ws.splitFocusedPane(direction: .vertical)) // P2 / P3, focus on P3
        let p4 = try #require(ws.splitFocusedPane(direction: .horizontal)) // P3 | P4, focus on P4

        #expect(ws.allPanes.count == 4)
        let paneOrder = ws.allPanes.map(\.id)

        // Verify rects cover full space
        let rects = ws.rootNode.paneRects()
        #expect(rects.count == 4)
        assertRectsSpanFullArea(rects)

        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        let rws = restored.workspaces[0]
        #expect(rws.allPanes.count == 4)
        #expect(rws.allPanes.map(\.id) == paneOrder)

        let restoredRects = rws.rootNode.paneRects()
        #expect(restoredRects.count == 4)
        assertRectsSpanFullArea(restoredRects)

        // Verify specific pane IDs survived
        #expect(rws.findPane(id: p1.id) != nil)
        #expect(rws.findPane(id: p2.id) != nil)
        #expect(rws.findPane(id: p3.id) != nil)
        #expect(rws.findPane(id: p4.id) != nil)
    }

    @Test func removeMiddlePaneCollapsesThenPersists() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))
        let p3 = try #require(ws.splitFocusedPane(direction: .horizontal))

        #expect(ws.allPanes.count == 3)

        // Remove middle pane (p2)
        ws.removePane(id: p2.id)
        #expect(ws.allPanes.count == 2)
        #expect(ws.findPane(id: p2.id) == nil)
        #expect(ws.findPane(id: p1.id) != nil)
        #expect(ws.findPane(id: p3.id) != nil)

        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        let rws = restored.workspaces[0]
        #expect(rws.allPanes.count == 2)
        #expect(rws.findPane(id: p1.id) != nil)
        #expect(rws.findPane(id: p3.id) != nil)
    }

    @Test func removeAllPanesReplacesWithFresh() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))

        #expect(ws.allPanes.count == 2)

        // Remove both — order matters: remove non-last first, then the "last" triggers replacement
        ws.removePane(id: p2.id)
        #expect(ws.allPanes.count == 1)
        #expect(ws.allPanes[0].id == p1.id)

        ws.removePane(id: p1.id)
        // Last pane removal replaces with fresh pane
        #expect(ws.allPanes.count == 1)
        let fresh = ws.allPanes[0]
        #expect(fresh.id != p1.id)
        #expect(fresh.id != p2.id)
        #expect(fresh.name == "Pane 3") // counter incremented: original 1, split 2, fresh 3
    }

    @Test func focusNavigationAfterRemoval() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))
        ws.focusPane(id: p2.id)
        let p3 = try #require(ws.splitFocusedPane(direction: .vertical))
        ws.focusPane(id: p3.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        #expect(ws.allPanes.count == 4)

        // Focus P3, remove it — focus should move to firstPane
        ws.focusPane(id: p3.id)
        #expect(ws.focusedPaneID == p3.id)

        ws.removePane(id: p3.id)
        #expect(ws.focusedPaneID == ws.rootNode.firstPane()?.id)

        // Remove focused pane again
        let currentFocused = try #require(ws.focusedPaneID)
        ws.removePane(id: currentFocused)
        #expect(ws.focusedPaneID == ws.rootNode.firstPane()?.id)
    }

    @Test func paneRectsConsistentAfterMutations() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))
        ws.focusPane(id: p2.id)
        _ = try #require(ws.splitFocusedPane(direction: .vertical))

        // 3 panes: check rects
        var rects = ws.rootNode.paneRects()
        #expect(rects.count == 3)
        assertRectsSpanFullArea(rects)

        // Remove a pane, check rects again
        ws.removePane(id: p2.id)
        rects = ws.rootNode.paneRects()
        #expect(rects.count == 2)
        assertRectsSpanFullArea(rects)

        // Persist + reload, check rects
        model.saveWorkspaces()
        let restored = reloadModel(from: url)
        let restoredRects = restored.workspaces[0].rootNode.paneRects()
        #expect(restoredRects.count == 2)
        assertRectsSpanFullArea(restoredRects)
    }
}

// MARK: - Suite D: Pane Swap

@MainActor
struct PaneSwapIntegration {
    @Test func swapPanesPreservesStructureAndPersists() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        p1.customName = "Editor"
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))
        p2.customName = "Shell"

        // Verify initial order
        #expect(ws.allPanes[0].id == p1.id)
        #expect(ws.allPanes[1].id == p2.id)

        // Swap
        let result = ws.swapPanes(p1.id, p2.id)
        #expect(result == true)
        #expect(ws.allPanes[0].id == p2.id)
        #expect(ws.allPanes[1].id == p1.id)

        // Tree structure preserved (still horizontal split at root)
        if case let .split(dir, _, _) = ws.rootNode.content {
            #expect(dir == .horizontal)
        } else {
            Issue.record("Expected split node at root")
        }

        // Persist and restore
        model.saveWorkspaces()
        let restored = reloadModel(from: url)
        let rws = restored.workspaces[0]
        #expect(rws.allPanes.count == 2)
        #expect(rws.allPanes[0].customName == "Shell")
        #expect(rws.allPanes[1].customName == "Editor")

        // Structure preserved after restore
        if case let .split(dir, _, _) = rws.rootNode.content {
            #expect(dir == .horizontal)
        } else {
            Issue.record("Expected split node at root after restore")
        }
    }
}

// MARK: - Suite E: Attention Flow

@MainActor
struct AttentionFlowIntegration {
    @Test func attentionOnUnfocusedPaneFocusClearsIt() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        // p2 is now focused; set attention on p1
        model.handlePaneNeedsAttention(p1.id, kind: .bell)
        #expect(p1.attentionKind == .bell)
        #expect(ws.hasAttention == true)

        // Focus p1 to clear attention
        ws.focusPane(id: p1.id)
        #expect(p1.attentionKind == nil)
        #expect(ws.hasAttention == false)
    }

    @Test func attentionAcrossMultipleWorkspaces() throws {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()
        model.selectedWorkspaceID = ws1.id

        // Split ws2 and set attention on its first pane
        let ws2p1 = ws2.allPanes[0]
        ws2.focusPane(id: ws2p1.id)
        _ = try #require(ws2.splitFocusedPane(direction: .horizontal))
        // ws2p2 is now focused in ws2; flag attention on ws2p1
        // But model.selectedWorkspaceID is ws1, so ws2p1 is unfocused from model perspective
        model.handlePaneNeedsAttention(ws2p1.id, kind: .bell)
        #expect(ws2.hasAttention == true)

        // Switch to ws2 and focus the attention pane
        model.selectedWorkspaceID = ws2.id
        ws2.focusPane(id: ws2p1.id)
        #expect(ws2p1.attentionKind == nil)
        #expect(ws2.hasAttention == false)
    }

    @Test func thinkingClearsAttentionStopRestoresClean() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        // Set attention on p1 (unfocused after split)
        model.handlePaneNeedsAttention(p1.id, kind: .bell)
        #expect(p1.attentionKind == .bell)

        // Thinking start clears attention
        model.handlePaneThinkingChanged(p1.id, isThinking: true)
        #expect(p1.attentionKind == nil)
        #expect(p1.isThinking == true)

        // Stop thinking — unfocused pane gets done attention
        model.handlePaneThinkingChanged(p1.id, isThinking: false)
        #expect(p1.isThinking == false)
        #expect(p1.attentionKind == .done)
    }

    @Test func bellOnFocusedPaneSetsBellAttention() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        // p1 is no longer focused after split; re-focus it
        ws.focusPane(id: p1.id)

        // Bell on focused pane should set .bell
        let didSet = model.handleBell(p1.id)
        #expect(didSet == true)
        #expect(p1.attentionKind == .bell)
    }

    @Test func bellOnUnfocusedPaneSetsBellAttention() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = try #require(ws.splitFocusedPane(direction: .horizontal))

        // p2 is focused after split; bell on p1 (unfocused) should set .bell
        let didSet = model.handleBell(p1.id)
        #expect(didSet == true)
        #expect(p1.attentionKind == .bell)

        // p2 (focused) should not be affected
        #expect(p2.attentionKind == nil)
    }

    @Test func bellAttentionClearsIndependently() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)

        // Bell on focused pane
        model.handleBell(p1.id)
        #expect(p1.attentionKind == .bell)

        // Simulate user interaction clearing the bell
        p1.attentionKind = nil
        #expect(p1.attentionKind == nil)
        #expect(ws.hasAttention == false)
    }

    @Test func attentionNotPersisted() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        // Set transient state
        model.handlePaneNeedsAttention(p1.id, kind: .bell)
        model.handlePaneThinkingChanged(p1.id, isThinking: true)
        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        let rp1 = try #require(restored.workspaces[0].findPane(id: p1.id))
        #expect(rp1.attentionKind == nil)
        #expect(rp1.isThinking == false)
    }
}

// MARK: - Suite E: Preferences Persistence

@MainActor
struct PreferencesPersistenceIntegration {
    @Test func themeAndWorkspacesPersistIndependently() {
        let (model, url) = makeModel()
        _ = model.addWorkspace()
        _ = model.addWorkspace()
        model.saveWorkspaces()

        // ThemeManager reads from ConfigFile; reloading workspaces with a fresh ConfigFile
        // gives default theme — verifies independence
        let restored = reloadModel(from: url)
        #expect(restored.workspaces.count == 3)
        #expect(restored.themeManager.selectedThemeName == "Catppuccin Mocha") // default from fresh config
    }

    @Test func soundSettingsIndependentOfWorkspaceStore() {
        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
        let configFile = ConfigFile(fileURL: cfgURL)
        let soundManager = SoundManager(configFile: configFile)
        soundManager.setSound(for: .bell, to: "Ping")

        // Modify workspaces independently
        let (model, url) = makeModel()
        _ = model.addWorkspace()
        model.saveWorkspaces()

        // Reload workspaces — sound config file is unaffected
        let restored = reloadModel(from: url)
        #expect(restored.workspaces.count == 2)

        let reloadedConfig = ConfigFile(fileURL: cfgURL)
        let reloadedSound = SoundManager(configFile: reloadedConfig)
        #expect(reloadedSound.sound(for: .bell) == "Ping")
    }

    @Test func themePersistsToConfigFile() {
        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
        let configFile = ConfigFile(fileURL: cfgURL)
        let catalog = ThemeCatalog(themesDirectory: nil)
        let manager = ThemeManager(configFile: configFile, themeCatalog: catalog)
        manager.selectedThemeName = "Catppuccin Macchiato"

        // Reload config and verify
        let reloadedConfig = ConfigFile(fileURL: cfgURL)
        let reloadedCatalog = ThemeCatalog(themesDirectory: nil)
        let reloadedManager = ThemeManager(configFile: reloadedConfig, themeCatalog: reloadedCatalog)
        #expect(reloadedManager.selectedThemeName == "Catppuccin Macchiato")
    }

    @Test func themeAndSoundShareConfigFile() {
        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
        let configFile = ConfigFile(fileURL: cfgURL)
        let themeCatalog = ThemeCatalog(themesDirectory: nil)
        let themeManager = ThemeManager(configFile: configFile, themeCatalog: themeCatalog)
        let soundManager = SoundManager(configFile: configFile)

        themeManager.selectedThemeName = "Catppuccin Frappe"
        soundManager.setSound(for: .bell, to: "Ping")

        // Both persisted to same file
        let reloadedConfig = ConfigFile(fileURL: cfgURL)
        #expect(reloadedConfig.get("theme") == "Catppuccin Frappe")
        #expect(reloadedConfig.get("hootty-bell-sound") == "Ping")
    }
}

// MARK: - Suite F: Split Enhancements

@MainActor
struct SplitEnhancementsIntegration {
    @Test func equalizePersistsAfterSaveReload() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        // Manually skew the ratio
        ws.rootNode.splitRatio = 0.3
        ws.equalizeSplits()
        #expect(abs(ws.rootNode.splitRatio - 0.5) < 0.001)

        model.saveWorkspaces()
        let restored = reloadModel(from: url)
        let rws = restored.workspaces[0]
        #expect(abs(rws.rootNode.splitRatio - 0.5) < 0.001)
    }

    @Test func chainEqualizationPersistsAfterSaveReload() throws {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        // Verify 3 equal panes
        let rects = ws.rootNode.paneRects()
        #expect(try abs(#require(rects.values.first?.width) - 1.0 / 3.0) < 0.001)

        model.saveWorkspaces()
        let restored = reloadModel(from: url)
        let restoredRects = restored.workspaces[0].rootNode.paneRects()
        #expect(restoredRects.count == 3)
        for (_, rect) in restoredRects {
            #expect(abs(rect.width - 1.0 / 3.0) < 0.001)
        }
    }

    @Test func splitRightFourTimesGivesFourEqualPanes() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))

        let rects = ws.rootNode.paneRects()
        #expect(rects.count == 4)
        for (_, rect) in rects {
            #expect(abs(rect.width - 0.25) < 0.001)
        }
    }
}

// MARK: - Suite G: Title-Based Claude Detection

@MainActor
struct TitleBasedClaudeDetection {
    @Test func titleAutoDetectsClaudeSession() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        let pane = ws.allPanes[0]
        #expect(pane.claudeSessionID == nil)

        model.handleTitleChange(pane.id, title: "\u{280B} Thinking...")
        #expect(pane.claudeSessionID == "auto")
        #expect(pane.isThinking == true)
    }

    @Test func autoDetectedSessionClearsOnNonClaudeTitle() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        let pane = ws.allPanes[0]

        model.handleTitleChange(pane.id, title: "\u{280B} Thinking...")
        #expect(pane.claudeSessionID == "auto")

        model.handleTitleChange(pane.id, title: "~/project")
        #expect(pane.claudeSessionID == nil)
        #expect(pane.isThinking == false)
    }

    @Test func claudeExitWhileThinkingSetsDoneOnUnfocusedPane() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))
        // p1 is now unfocused

        // Claude starts thinking (auto-detected)
        model.handleTitleChange(p1.id, title: "\u{280B} Thinking . project")
        #expect(p1.claudeSessionID == "auto")
        #expect(p1.isThinking == true)

        // Claude exits — title reverts to shell prompt (skips idle state)
        model.handleTitleChange(p1.id, title: "zsh")
        #expect(p1.claudeSessionID == nil)
        #expect(p1.isThinking == false)
        #expect(p1.attentionKind == .done)
    }

    @Test func claudeExitWhileThinkingOnFocusedPaneDoesNotSetDone() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let pane = ws.allPanes[0]
        ws.focusPane(id: pane.id)

        // Claude starts thinking (auto-detected)
        model.handleTitleChange(pane.id, title: "\u{280B} Thinking . project")
        #expect(pane.isThinking == true)

        // Claude exits on focused pane — no done attention
        model.handleTitleChange(pane.id, title: "zsh")
        #expect(pane.claudeSessionID == nil)
        #expect(pane.isThinking == false)
        #expect(pane.attentionKind == nil)
    }

    @Test func titleIdleSetsDoneOnUnfocusedPane() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        p1.claudeSessionID = "test-session"
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))
        // p1 is now unfocused

        // Simulate thinking start
        model.handleTitleChange(p1.id, title: "\u{280B} Thinking . project")
        #expect(p1.isThinking == true)

        // Simulate idle (Claude finished) — done attention on unfocused pane
        model.handleTitleChange(p1.id, title: "\u{2733} project")
        #expect(p1.isThinking == false)
        #expect(p1.attentionKind == .done)
    }

    @Test func rapidTitleUpdatesAreIdempotent() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        let pane = ws.allPanes[0]
        pane.claudeSessionID = "test-session"

        // Multiple spinner frames should all result in thinking=true
        let spinnerChars = ["\u{280B}", "\u{2819}", "\u{2839}", "\u{2838}", "\u{283C}"]
        for char in spinnerChars {
            model.handleTitleChange(pane.id, title: "\(char) Thinking . project")
        }
        #expect(pane.isThinking == true)
        #expect(pane.attentionKind == nil)
    }

    @Test func hookAndTitleDetectionCoexist() throws {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        p1.claudeSessionID = "test-session"
        ws.focusPane(id: p1.id)
        _ = try #require(ws.splitFocusedPane(direction: .horizontal))
        // p1 is now unfocused

        // Title-based thinking detection fires first
        model.handleTitleChange(p1.id, title: "\u{280B} Thinking . project")
        #expect(p1.isThinking == true)

        // Hook-based thinking fires later — should be a no-op (already thinking)
        model.handlePaneThinkingChanged(p1.id, isThinking: true)
        #expect(p1.isThinking == true)
        #expect(p1.attentionKind == nil)

        // Title-based idle fires — done attention on unfocused pane
        model.handleTitleChange(p1.id, title: "* project")
        #expect(p1.isThinking == false)
        #expect(p1.attentionKind == .done)

        // Hook-based idle fires later — already not thinking, no change
        model.handlePaneThinkingChanged(p1.id, isThinking: false)
        #expect(p1.isThinking == false)
        #expect(p1.attentionKind == .done)
    }

    @Test func bellDuringThinkingIsSuppressed() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let pane = ws.allPanes[0]
        pane.claudeSessionID = "test-session"

        // Start thinking
        model.handleTitleChange(pane.id, title: "\u{280B} Thinking . project")
        #expect(pane.isThinking == true)
        #expect(pane.attentionKind == nil)

        // Bell during thinking — should be suppressed
        let didSet = model.handleBell(pane.id)
        #expect(didSet == false)
        #expect(pane.attentionKind == nil)
        #expect(pane.isThinking == true)
    }

    @Test func titleIdleOnFocusedPaneDoesNotSetDone() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let pane = ws.allPanes[0]
        pane.claudeSessionID = "test-session"
        ws.focusPane(id: pane.id)
        // Single pane — it is the focused pane

        // Start thinking
        model.handleTitleChange(pane.id, title: "\u{280B} Thinking . project")
        #expect(pane.isThinking == true)

        // Idle on focused pane — no done attention
        model.handleTitleChange(pane.id, title: "\u{2733} project")
        #expect(pane.isThinking == false)
        #expect(pane.attentionKind == nil)
    }
}

// MARK: - Suite G2: Manual Flag Attention

@MainActor
struct ManualFlagAttention {
    @Test func noteToggleOnPane() {
        let pane = Pane(name: "Test")

        #expect(!pane.hasNote)
        pane.setNote("remember this")
        #expect(pane.hasNote)
        #expect(pane.note == "remember this")

        pane.setNote(nil)
        #expect(!pane.hasNote)
        #expect(pane.note == nil)
    }

    @Test func noteIndependentOfAttention() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        let pane = ws.allPanes[0]

        pane.setNote("remember this")
        pane.attentionKind = .bell
        #expect(pane.hasNote)
        #expect(pane.attentionKind == .bell)

        pane.attentionKind = nil
        #expect(pane.hasNote)
    }

    @Test func noteNotClearedByThinkingStart() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id
        let pane = ws.allPanes[0]
        pane.claudeSessionID = "test"

        pane.setNote("remember this")
        model.handleTitleChange(pane.id, title: "\u{280B} Thinking...")
        #expect(pane.isThinking == true)
        #expect(pane.hasNote)
    }

    @Test func noteNotClearedByBell() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        let pane = ws.allPanes[0]

        pane.setNote("remember this")
        let didSet = model.handleBell(pane.id)
        #expect(didSet == true)
        #expect(pane.attentionKind == .bell)
        #expect(pane.hasNote)
    }

    @Test func emptyNoteStringClearsNote() {
        let pane = Pane(name: "Test")
        pane.setNote("remember this")
        #expect(pane.hasNote)

        pane.setNote("")
        #expect(!pane.hasNote)
    }
}

// MARK: - Suite H: Sidebar Sections

@MainActor
struct SidebarSectionsIntegration {
    @Test func sidebarSectionsUpdateWhenBranchChanges() {
        let repo = "/Users/test/project"
        let pA = Pane(name: "A", branch: "main", repoRoot: repo)
        let pB = Pane(name: "B", branch: "main", repoRoot: repo)
        let ws = Workspace(
            id: UUID(), name: "Test",
            headBranches: [repo: "main"],
            rootNode: SplitNode(
                direction: .horizontal,
                first: SplitNode(pane: pA),
                second: SplitNode(pane: pB)
            ),
            focusedPaneID: pA.id
        )

        // Initially all on main
        #expect(ws.sidebarSections.count == 1)
        #expect(ws.sidebarSections[0].branch == "main")
        #expect(ws.sidebarSections[0].panes.count == 2)

        // Change pB's branch
        pB.branch = "feature"
        let sections = ws.sidebarSections
        #expect(sections.count == 2)
        #expect(sections[0].branch == "main")
        #expect(sections[0].isHead == true)
        #expect(sections[0].panes.count == 1)
        #expect(sections[1].branch == "feature")
        #expect(sections[1].panes.count == 1)
    }

    @Test func multiRepoSidebarSectionsStaySeparate() {
        let repoA = "/Users/test/frontend"
        let repoB = "/Users/test/backend"
        let pA = Pane(name: "A", branch: "main", repoRoot: repoA)
        let pB = Pane(name: "B", branch: "main", repoRoot: repoB)
        let pC = Pane(name: "C", branch: "feature", repoRoot: repoA)
        let ws = Workspace(
            id: UUID(), name: "Test",
            headBranches: [repoA: "main", repoB: "main"],
            rootNode: SplitNode(
                direction: .horizontal,
                first: SplitNode(
                    direction: .vertical,
                    first: SplitNode(pane: pA),
                    second: SplitNode(pane: pB)
                ),
                second: SplitNode(pane: pC)
            ),
            focusedPaneID: pA.id
        )

        let sections = ws.sidebarSections
        // Two HEAD sections (frontend/main, backend/main) + one non-head (frontend/feature)
        #expect(sections.count == 3)

        // HEAD sections first, in tree traversal order
        #expect(sections[0].isHead == true)
        #expect(sections[1].isHead == true)
        #expect(sections[0].repoDisplayName == "frontend")
        #expect(sections[1].repoDisplayName == "backend")

        // Non-head last
        #expect(sections[2].isHead == false)
        #expect(sections[2].displayLabel == "frontend/feature")
    }
}

// MARK: - Helpers

/// Verify that pane rects tile the full [0,0,1,1] area by checking total area ≈ 1.0
/// and no gaps (all rects are within bounds).
private func assertRectsSpanFullArea(
    _ rects: [UUID: CGRect],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let totalArea = rects.values.reduce(0.0) { $0 + $1.width * $1.height }
    #expect(
        abs(totalArea - 1.0) < 0.001,
        "Total pane area should be ~1.0, got \(totalArea)",
        sourceLocation: sourceLocation
    )
    for (_, rect) in rects {
        #expect(rect.minX >= -0.001, sourceLocation: sourceLocation)
        #expect(rect.minY >= -0.001, sourceLocation: sourceLocation)
        #expect(rect.maxX <= 1.001, sourceLocation: sourceLocation)
        #expect(rect.maxY <= 1.001, sourceLocation: sourceLocation)
    }
}

// MARK: - Suite: Workspace Collapse Persistence

@MainActor
struct WorkspaceCollapseIntegration {
    @Test func collapseStatePersistsThroughSaveLoadRoundTrip() {
        let (model, url) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()

        // Collapse ws1
        model.toggleWorkspaceCollapse(ws1.id)
        #expect(model.collapsedWorkspaceIDs.contains(ws1.id))
        #expect(!model.collapsedWorkspaceIDs.contains(ws2.id))
        model.saveWorkspaces()

        // Reload
        let restored = reloadModel(from: url)
        #expect(restored.collapsedWorkspaceIDs.contains(ws1.id))
        #expect(!restored.collapsedWorkspaceIDs.contains(ws2.id))
    }

    @Test func effectiveCollapseRespectsSelectedWorkspace() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()

        model.selectedWorkspaceID = ws1.id
        model.toggleWorkspaceCollapse(ws1.id)

        // ws1 is collapsed but selected — not effectively collapsed
        #expect(!model.isWorkspaceEffectivelyCollapsed(ws1.id))
        // ws2 is not collapsed at all
        #expect(!model.isWorkspaceEffectivelyCollapsed(ws2.id))

        // Switch selection to ws2
        model.selectedWorkspaceID = ws2.id
        // Now ws1 is effectively collapsed
        #expect(model.isWorkspaceEffectivelyCollapsed(ws1.id))
    }

    @Test func removeWorkspaceCleansCollapsedIDs() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        _ = model.addWorkspace()

        model.toggleWorkspaceCollapse(ws1.id)
        #expect(model.collapsedWorkspaceIDs.contains(ws1.id))

        model.removeWorkspace(id: ws1.id)
        #expect(!model.collapsedWorkspaceIDs.contains(ws1.id))
    }

    @Test func collapseAllAndExpandAll() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()

        model.collapseAllWorkspaces()
        #expect(model.collapsedWorkspaceIDs.contains(ws1.id))
        #expect(model.collapsedWorkspaceIDs.contains(ws2.id))

        model.expandAllWorkspaces()
        #expect(model.collapsedWorkspaceIDs.isEmpty)
    }
}

// MARK: - Suite: Sidebar Keyboard Navigation

@MainActor
struct SidebarKeyboardNavTests {
    @Test func navigableItemsIncludeWorkspaceRows() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let pane1 = ws1.allPanes[0]

        let items = SidebarKeyboardNav.allNavigableItems(
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [],
            selectedWorkspaceID: ws1.id
        )

        #expect(items.count == 2) // workspace row + 1 pane
        #expect(items[0] == .workspace(ws1.id))
        #expect(items[1] == .pane(workspaceID: ws1.id, paneID: pane1.id))
    }

    @Test func collapsedWorkspaceSkipsPanes() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()
        model.selectedWorkspaceID = ws1.id

        // Collapse ws2 (not selected)
        let items = SidebarKeyboardNav.allNavigableItems(
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [ws2.id],
            selectedWorkspaceID: ws1.id
        )

        // ws1 row + ws1 pane + ws2 row (no ws2 pane)
        #expect(items.count == 3)
        #expect(items[2] == .workspace(ws2.id))
    }

    @Test func selectedCollapsedWorkspaceShowsPanes() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]

        // ws1 is both collapsed AND selected — panes should still show
        let items = SidebarKeyboardNav.allNavigableItems(
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [ws1.id],
            selectedWorkspaceID: ws1.id
        )

        #expect(items.count == 2) // workspace row + pane
    }

    @Test func moveCursorAcrossWorkspaceBoundary() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()
        let pane1 = ws1.allPanes[0]
        model.selectedWorkspaceID = ws1.id

        // Start on pane1, move down should go to ws2 row
        let next = SidebarKeyboardNav.moveCursor(
            direction: 1,
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [],
            selectedWorkspaceID: ws1.id,
            currentTarget: .pane(pane1.id)
        )
        #expect(next == .workspace(ws2.id))

        // From ws2 row, move down should go to ws2's pane
        let pane2 = ws2.allPanes[0]
        let next2 = SidebarKeyboardNav.moveCursor(
            direction: 1,
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [],
            selectedWorkspaceID: ws1.id,
            currentTarget: .workspace(ws2.id)
        )
        #expect(next2 == .pane(pane2.id))
    }

    @Test func moveCursorClampsAtBounds() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]

        // At the top, moving up should stay at first item
        let result = SidebarKeyboardNav.moveCursor(
            direction: -1,
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [],
            selectedWorkspaceID: ws1.id,
            currentTarget: .workspace(ws1.id)
        )
        #expect(result == .workspace(ws1.id))
    }

    @Test func confirmCursorResolvesWorkspaceAndPane() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let pane1 = ws1.allPanes[0]

        let wsResult = SidebarKeyboardNav.confirmCursor(
            target: .workspace(ws1.id),
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [],
            selectedWorkspaceID: ws1.id
        )
        #expect(wsResult == .workspace(ws1.id))

        let paneResult = SidebarKeyboardNav.confirmCursor(
            target: .pane(pane1.id),
            workspaces: model.workspaces,
            collapsedWorkspaceIDs: [],
            selectedWorkspaceID: ws1.id
        )
        #expect(paneResult == .pane(workspaceID: ws1.id, paneID: pane1.id))
    }
}
