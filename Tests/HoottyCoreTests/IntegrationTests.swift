import Testing
import Foundation
@testable import HoottyCore

// MARK: - Helpers

private func makeModel() -> (AppModel, URL) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".json")
    let cfgURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("hootty-test-\(UUID().uuidString)")
        .appendingPathComponent("config")
    return (AppModel(workspaceStore: WorkspaceStore(fileURL: url), configFile: ConfigFile(fileURL: cfgURL)), url)
}

private func reloadModel(from url: URL) -> AppModel {
    let cfgURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("hootty-test-\(UUID().uuidString)")
        .appendingPathComponent("config")
    return AppModel(workspaceStore: WorkspaceStore(fileURL: url), configFile: ConfigFile(fileURL: cfgURL))
}

// MARK: - Suite A: Workspace Lifecycle

@Suite struct WorkspaceLifecycleIntegration {
    @Test func createSplitRenamePersistRestore() {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        // Split horizontally from initial pane, then vertically from the new pane
        let pane1 = ws.allPanes[0]
        pane1.customName = "Editor"
        let pane2 = ws.splitFocusedPane(direction: .horizontal)!
        pane2.customName = "Shell"
        let pane3 = ws.splitFocusedPane(direction: .vertical)!
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

    @Test func workingDirectoryAndShellPreservedThroughPersistence() {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]
        let pane1 = ws.allPanes[0]
        pane1.shell = "/bin/bash"
        pane1.workingDirectory = "/tmp/project"

        // Split inherits shell + workingDirectory from focused pane
        ws.focusPane(id: pane1.id)
        let pane2 = ws.splitFocusedPane(direction: .horizontal)!

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

@Suite struct MultiWorkspaceIntegration {
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

@Suite struct SplitTreeIntegration {
    @Test func deepNestedSplitPersistRestore() {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        // Start: single pane (P1). Build asymmetric 4-pane tree:
        // H split → left has P1, right gets V split → top P2, bottom gets H split → P3, P4
        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)! // P1 | P2, focus on P2
        let p3 = ws.splitFocusedPane(direction: .vertical)!   // P2 / P3, focus on P3
        let p4 = ws.splitFocusedPane(direction: .horizontal)! // P3 | P4, focus on P4

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

    @Test func removeMiddlePaneCollapsesThenPersists() {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        let p3 = ws.splitFocusedPane(direction: .horizontal)!

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

    @Test func removeAllPanesReplacesWithFresh() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!

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

    @Test func focusNavigationAfterRemoval() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        ws.focusPane(id: p2.id)
        let p3 = ws.splitFocusedPane(direction: .vertical)!
        ws.focusPane(id: p3.id)
        _ = ws.splitFocusedPane(direction: .horizontal)!

        #expect(ws.allPanes.count == 4)

        // Focus P3, remove it — focus should move to firstPane
        ws.focusPane(id: p3.id)
        #expect(ws.focusedPaneID == p3.id)

        ws.removePane(id: p3.id)
        #expect(ws.focusedPaneID == ws.rootNode.firstPane()?.id)

        // Remove focused pane again
        let currentFocused = ws.focusedPaneID!
        ws.removePane(id: currentFocused)
        #expect(ws.focusedPaneID == ws.rootNode.firstPane()?.id)
    }

    @Test func paneRectsConsistentAfterMutations() {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        ws.focusPane(id: p2.id)
        _ = ws.splitFocusedPane(direction: .vertical)!

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

// MARK: - Suite D: Attention Flow

@Suite struct AttentionFlowIntegration {
    @Test func attentionOnUnfocusedPaneFocusClearsIt() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = ws.splitFocusedPane(direction: .horizontal)!

        // p2 is now focused; set attention on p1
        model.handlePaneNeedsAttention(p1.id, kind: .input)
        #expect(p1.attentionKind == .input)
        #expect(ws.hasAttention == true)

        // Focus p1 to clear attention
        ws.focusPane(id: p1.id)
        #expect(p1.attentionKind == nil)
        #expect(ws.hasAttention == false)
    }

    @Test func attentionAcrossMultipleWorkspaces() {
        let (model, _) = makeModel()
        let ws1 = model.workspaces[0]
        let ws2 = model.addWorkspace()
        model.selectedWorkspaceID = ws1.id

        // Split ws2 and set attention on its first pane
        let ws2p1 = ws2.allPanes[0]
        ws2.focusPane(id: ws2p1.id)
        _ = ws2.splitFocusedPane(direction: .horizontal)!
        // ws2p2 is now focused in ws2; flag attention on ws2p1
        // But model.selectedWorkspaceID is ws1, so ws2p1 is unfocused from model perspective
        model.handlePaneNeedsAttention(ws2p1.id, kind: .idle)
        #expect(ws2.hasAttention == true)

        // Switch to ws2 and focus the attention pane
        model.selectedWorkspaceID = ws2.id
        ws2.focusPane(id: ws2p1.id)
        #expect(ws2p1.attentionKind == nil)
        #expect(ws2.hasAttention == false)
    }

    @Test func thinkingClearsAttentionStopRestoresClean() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = ws.splitFocusedPane(direction: .horizontal)!

        // Set attention on p1 (unfocused after split)
        model.handlePaneNeedsAttention(p1.id, kind: .idle)
        #expect(p1.attentionKind == .idle)

        // Thinking start clears attention
        model.handlePaneThinkingChanged(p1.id, isThinking: true)
        #expect(p1.attentionKind == nil)
        #expect(p1.isThinking == true)

        // Stop thinking
        model.handlePaneThinkingChanged(p1.id, isThinking: false)
        #expect(p1.isThinking == false)
        #expect(p1.attentionKind == nil)
    }

    @Test func attentionPriorityInputOverIdle() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!
        let p3 = ws.splitFocusedPane(direction: .vertical)!

        // Focus p3 so p1 and p2 are unfocused
        ws.focusPane(id: p3.id)

        // Set idle on p1, input on p2
        model.handlePaneNeedsAttention(p1.id, kind: .idle)
        model.handlePaneNeedsAttention(p2.id, kind: .input)

        #expect(ws.attentionKind == .input)

        // Clear p2's attention — should fall back to idle
        p2.attentionKind = nil
        #expect(ws.attentionKind == .idle)

        // Clear p1 too
        p1.attentionKind = nil
        #expect(ws.attentionKind == nil)
    }

    @Test func bellOnFocusedPaneSetsBellAttention() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = ws.splitFocusedPane(direction: .horizontal)!

        // p1 is no longer focused after split; re-focus it
        ws.focusPane(id: p1.id)

        // Bell on focused pane should set .bell
        let didSet = model.handleBell(p1.id)
        #expect(didSet == true)
        #expect(p1.attentionKind == .bell)
    }

    @Test func bellOnUnfocusedPaneSetsInputAttention() {
        let (model, _) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        let p2 = ws.splitFocusedPane(direction: .horizontal)!

        // p2 is focused after split; bell on p1 (unfocused) should set .input
        let didSet = model.handleBell(p1.id)
        #expect(didSet == true)
        #expect(p1.attentionKind == .input)

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

    @Test func attentionNotPersisted() {
        let (model, url) = makeModel()
        let ws = model.workspaces[0]
        model.selectedWorkspaceID = ws.id

        let p1 = ws.allPanes[0]
        ws.focusPane(id: p1.id)
        _ = ws.splitFocusedPane(direction: .horizontal)!

        // Set transient state
        model.handlePaneNeedsAttention(p1.id, kind: .input)
        model.handlePaneThinkingChanged(p1.id, isThinking: true)
        model.saveWorkspaces()

        let restored = reloadModel(from: url)
        let rp1 = restored.workspaces[0].findPane(id: p1.id)!
        #expect(rp1.attentionKind == nil)
        #expect(rp1.isThinking == false)
    }
}

// MARK: - Suite E: Preferences Persistence

@Suite struct PreferencesPersistenceIntegration {
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
        soundManager.bellSound = "Ping"
        soundManager.attentionInputSound = "Basso"

        // Modify workspaces independently
        let (model, url) = makeModel()
        _ = model.addWorkspace()
        model.saveWorkspaces()

        // Reload workspaces — sound config file is unaffected
        let restored = reloadModel(from: url)
        #expect(restored.workspaces.count == 2)

        let reloadedConfig = ConfigFile(fileURL: cfgURL)
        let reloadedSound = SoundManager(configFile: reloadedConfig)
        #expect(reloadedSound.bellSound == "Ping")
        #expect(reloadedSound.attentionInputSound == "Basso")
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
        soundManager.bellSound = "Ping"

        // Both persisted to same file
        let reloadedConfig = ConfigFile(fileURL: cfgURL)
        #expect(reloadedConfig.get("theme") == "Catppuccin Frappe")
        #expect(reloadedConfig.get("hootty-bell-sound") == "Ping")
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
