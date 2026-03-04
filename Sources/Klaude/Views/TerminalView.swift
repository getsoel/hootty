import SwiftUI
import KlaudeCore

struct TerminalPanel: NSViewRepresentable {
    let session: Session

    func makeNSView(context: Context) -> TerminalSurfaceView {
        guard let app = GhosttyApp.shared.app else {
            fatalError("GhosttyApp not initialized")
        }

        let view = TerminalSurfaceView(app: app, workingDirectory: session.workingDirectory)

        // Wire callbacks
        view.titleDidChange = { [weak session] title in
            session?.name = title
        }
        view.pwdDidChange = { [weak session] pwd in
            session?.workingDirectory = pwd
        }
        view.processDidExit = { [weak session] _ in
            session?.isRunning = false
        }

        // Focus the view
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ view: TerminalSurfaceView, context: Context) {}
}
