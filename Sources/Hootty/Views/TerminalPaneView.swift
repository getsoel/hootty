import SwiftUI
import HoottyCore

struct TerminalPaneView: NSViewRepresentable {
    let pane: Pane
    let isFocused: Bool

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

        view.titleDidChange = { [weak pane] title in
            if pane?.customName == nil {
                pane?.name = title
            }
        }
        view.pwdDidChange = { [weak pane] pwd in
            pane?.workingDirectory = pwd
        }
        view.processDidExit = { [weak pane] _ in
            pane?.isRunning = false
            pane?.claudeSessionID = nil
            if let paneID = pane?.id {
                GhosttyApp.requestCloseSurface(paneID: paneID)
            }
        }

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
        if isFocused {
            DispatchQueue.main.async {
                if view.window?.firstResponder !== view {
                    view.window?.makeFirstResponder(view)
                }
            }
        }
    }
}
