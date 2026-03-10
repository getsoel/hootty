import Testing
import Foundation
@testable import HoottyCore

@Suite struct AppCommandTests {
    @Test func allCommandsHaveNonEmptyTitle() {
        for command in AppCommand.allCases {
            #expect(!command.title.isEmpty, "AppCommand.\(command.rawValue) has empty title")
        }
    }

    @Test func allCommandsHaveUniqueRawValues() {
        let rawValues = AppCommand.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test func shortcutHintIsNilOrNonEmpty() {
        for command in AppCommand.allCases {
            if let hint = command.shortcutHint {
                #expect(!hint.isEmpty, "AppCommand.\(command.rawValue) has empty shortcut hint")
            }
        }
    }

    @Test func idMatchesRawValue() {
        for command in AppCommand.allCases {
            #expect(command.id == command.rawValue)
        }
    }
}

@Suite struct WorkspaceNavigationTests {
    private func makeModel() -> AppModel {
        let wsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
        return AppModel(workspaceStore: WorkspaceStore(fileURL: wsURL), configFile: ConfigFile(fileURL: cfgURL))
    }

    @Test func selectNextWorkspaceAdvances() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = first.id

        model.selectNextWorkspace()
        #expect(model.selectedWorkspaceID == second.id)
    }

    @Test func selectNextWorkspaceWrapsToFirst() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id

        model.selectNextWorkspace()
        #expect(model.selectedWorkspaceID == first.id)
    }

    @Test func selectPreviousWorkspaceGoesBack() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id

        model.selectPreviousWorkspace()
        #expect(model.selectedWorkspaceID == first.id)
    }

    @Test func selectPreviousWorkspaceWrapsToLast() {
        let model = makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = first.id

        model.selectPreviousWorkspace()
        #expect(model.selectedWorkspaceID == second.id)
    }
}

@Suite struct PaneNavigationTests {
    @Test func focusNextPaneWrapsAround() {
        let workspace = Workspace(name: "Test")
        let firstPaneID = workspace.focusedPaneID!
        _ = workspace.splitFocusedPane(direction: .horizontal)
        let secondPaneID = workspace.focusedPaneID!

        // Now focused on second pane, go next should wrap to first
        workspace.focusNextPane()
        #expect(workspace.focusedPaneID == firstPaneID)

        // Go next again should go to second
        workspace.focusNextPane()
        #expect(workspace.focusedPaneID == secondPaneID)
    }

    @Test func focusPreviousPaneWrapsAround() {
        let workspace = Workspace(name: "Test")
        let firstPaneID = workspace.focusedPaneID!
        _ = workspace.splitFocusedPane(direction: .horizontal)

        // Focus first pane, then go previous should wrap to last
        workspace.focusPane(id: firstPaneID)
        workspace.focusPreviousPane()
        #expect(workspace.focusedPaneID != firstPaneID)
    }

    @Test func focusNextPaneNoOpWithSinglePane() {
        let workspace = Workspace(name: "Test")
        let onlyPaneID = workspace.focusedPaneID!

        workspace.focusNextPane()
        #expect(workspace.focusedPaneID == onlyPaneID)
    }

    @Test func focusPreviousPaneNoOpWithSinglePane() {
        let workspace = Workspace(name: "Test")
        let onlyPaneID = workspace.focusedPaneID!

        workspace.focusPreviousPane()
        #expect(workspace.focusedPaneID == onlyPaneID)
    }
}
