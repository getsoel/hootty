import SwiftUI
import KlaudeCore

struct TerminalPaneView: NSViewRepresentable {
    let pane: Pane
    let isFocused: Bool

    func makeNSView(context: Context) -> TerminalSurfaceView {
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
            pane?.name = title
        }
        view.pwdDidChange = { [weak pane] pwd in
            pane?.workingDirectory = pwd
        }
        view.processDidExit = { [weak pane] _ in
            pane?.isRunning = false
            if let paneID = pane?.id {
                GhosttyApp.requestCloseSurface(paneID: paneID)
            }
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
