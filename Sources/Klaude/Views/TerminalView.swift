import SwiftUI
import SwiftTerm

struct TerminalPanel: NSViewRepresentable {
    let session: Session
    let theme: TerminalTheme

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        view.optionAsMetaKey = true
        theme.apply(to: view)

        view.startProcess(
            executable: session.shell,
            execName: "-" + (session.shell as NSString).lastPathComponent,
            currentDirectory: session.workingDirectory
        )

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ view: LocalProcessTerminalView, context: Context) {
        if theme != context.coordinator.currentTheme {
            context.coordinator.currentTheme = theme
            theme.apply(to: view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, theme: theme)
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let session: Session
        var currentTheme: TerminalTheme

        init(session: Session, theme: TerminalTheme) {
            self.session = session
            self.currentTheme = theme
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async { [weak self] in
                self?.session.name = title
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { [weak self] in
                self?.session.isRunning = false
            }
        }
    }
}
