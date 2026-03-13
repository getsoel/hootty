import SwiftUI
import HoottyCore

private struct SidebarHasFocusKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sidebarHasFocus: Bool {
        get { self[SidebarHasFocusKey.self] }
        set { self[SidebarHasFocusKey.self] = newValue }
    }
}

struct TerminalPaneView: NSViewRepresentable {
    let pane: Pane
    let isFocused: Bool
    let onFocusPane: () -> Void
    @Environment(\.sidebarHasFocus) private var sidebarHasFocus

    func makeNSView(context: Context) -> TerminalSurfaceView {
        // Reuse cached view if available (survives SwiftUI structural identity changes)
        if let cached = GhosttyApp.shared.cachedSurfaceView(for: pane.id) {
            return cached
        }

        guard let app = GhosttyApp.shared.app else {
            fatalError("GhosttyApp not initialized")
        }

        let parentSurface = GhosttyApp.shared.consumeParentSurface(for: pane.id)

        let view = TerminalSurfaceView(
            app: app,
            paneID: pane.id,
            workingDirectory: pane.workingDirectory,
            parentSurface: parentSurface
        )

        var pendingTitleUpdate: DispatchWorkItem?
        view.titleDidChange = { [weak pane] title in
            guard let pane, pane.customName == nil, pane.claudeSessionID != nil else { return }
            pendingTitleUpdate?.cancel()
            let work = DispatchWorkItem { [weak pane] in
                guard let pane, pane.customName == nil else { return }
                if let clean = ClaudeTitleParser.stripPrefix(title) {
                    pane.name = clean
                }
            }
            pendingTitleUpdate = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
        view.pwdDidChange = { [weak pane] pwd in
            pane?.workingDirectory = pwd
        }
        view.processDidExit = { [weak pane] _ in
            pane?.isRunning = false
            pane?.isThinking = false
            pane?.claudeSessionID = nil
            if let paneID = pane?.id {
                GhosttyApp.requestCloseSurface(paneID: paneID)
            }
        }
        view.onUserInteraction = { [weak pane] in
            if pane?.attentionKind == .bell {
                pane?.attentionKind = nil
            }
        }
        view.onFocusRequest = onFocusPane

        GhosttyApp.shared.cacheSurfaceView(view, for: pane.id)

        if let command = GhosttyApp.shared.consumePendingCommand(for: pane.id) {
            view.queueText(command)
        }

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ view: TerminalSurfaceView, context: Context) {
        view.onFocusRequest = onFocusPane
        if isFocused && !sidebarHasFocus {
            DispatchQueue.main.async {
                if view.window?.firstResponder !== view {
                    view.window?.makeFirstResponder(view)
                }
            }
        }
    }
}
