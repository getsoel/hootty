import Foundation
import Testing
@testable import HoottyCore

struct AppCommandTests {
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

@MainActor
struct WorkspaceNavigationTests {
    @Test func selectNextWorkspaceAdvances() {
        let model = TestHelpers.makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = first.id

        model.selectNextWorkspace()
        #expect(model.selectedWorkspaceID == second.id)
    }

    @Test func selectNextWorkspaceWrapsToFirst() {
        let model = TestHelpers.makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id

        model.selectNextWorkspace()
        #expect(model.selectedWorkspaceID == first.id)
    }

    @Test func selectPreviousWorkspaceGoesBack() {
        let model = TestHelpers.makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = second.id

        model.selectPreviousWorkspace()
        #expect(model.selectedWorkspaceID == first.id)
    }

    @Test func selectPreviousWorkspaceWrapsToLast() {
        let model = TestHelpers.makeModel()
        let first = model.workspaces[0]
        let second = model.addWorkspace()
        model.selectedWorkspaceID = first.id

        model.selectPreviousWorkspace()
        #expect(model.selectedWorkspaceID == second.id)
    }
}

@MainActor
struct PaneNavigationTests {
    @Test func focusNextPaneWrapsAround() throws {
        let workspace = Workspace(name: "Test")
        let firstPaneID = try #require(workspace.focusedPaneID)
        _ = workspace.splitFocusedPane(direction: .horizontal)
        let secondPaneID = try #require(workspace.focusedPaneID)

        // Now focused on second pane, go next should wrap to first
        workspace.focusNextPane()
        #expect(workspace.focusedPaneID == firstPaneID)

        // Go next again should go to second
        workspace.focusNextPane()
        #expect(workspace.focusedPaneID == secondPaneID)
    }

    @Test func focusPreviousPaneWrapsAround() throws {
        let workspace = Workspace(name: "Test")
        let firstPaneID = try #require(workspace.focusedPaneID)
        _ = workspace.splitFocusedPane(direction: .horizontal)

        // Focus first pane, then go previous should wrap to last
        workspace.focusPane(id: firstPaneID)
        workspace.focusPreviousPane()
        #expect(workspace.focusedPaneID != firstPaneID)
    }

    @Test func focusNextPaneNoOpWithSinglePane() throws {
        let workspace = Workspace(name: "Test")
        let onlyPaneID = try #require(workspace.focusedPaneID)

        workspace.focusNextPane()
        #expect(workspace.focusedPaneID == onlyPaneID)
    }

    @Test func focusPreviousPaneNoOpWithSinglePane() throws {
        let workspace = Workspace(name: "Test")
        let onlyPaneID = try #require(workspace.focusedPaneID)

        workspace.focusPreviousPane()
        #expect(workspace.focusedPaneID == onlyPaneID)
    }
}
