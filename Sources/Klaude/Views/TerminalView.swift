import SwiftUI
import KlaudeCore

struct TerminalPanel: NSViewRepresentable {
    let tab: KlaudeCore.Tab

    func makeNSView(context: Context) -> TerminalSurfaceView {
        guard let app = GhosttyApp.shared.app else {
            fatalError("GhosttyApp not initialized")
        }

        let view = TerminalSurfaceView(app: app, tabID: tab.id, workingDirectory: tab.workingDirectory)

        // Wire callbacks
        view.titleDidChange = { [weak tab] title in
            tab?.name = title
        }
        view.pwdDidChange = { [weak tab] pwd in
            tab?.workingDirectory = pwd
        }
        view.processDidExit = { [weak tab] _ in
            tab?.isRunning = false
        }

        // Focus the view
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ view: TerminalSurfaceView, context: Context) {}
}
