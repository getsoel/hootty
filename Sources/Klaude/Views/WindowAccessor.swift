import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowObserverView {
        WindowObserverView(onWindow: onWindow)
    }

    func updateNSView(_ nsView: WindowObserverView, context: Context) {
        nsView.onWindow = onWindow
        if let window = nsView.window {
            onWindow(window)
        }
    }

    class WindowObserverView: NSView {
        var onWindow: (NSWindow) -> Void
        private var observations: [NSObjectProtocol] = []

        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observations.forEach { NotificationCenter.default.removeObserver($0) }
            observations.removeAll()
            guard let window else { return }
            onWindow(window)
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didChangeOcclusionStateNotification] {
                let obs = NotificationCenter.default.addObserver(
                    forName: name, object: window, queue: .main
                ) { [weak self] _ in
                    guard let self, let window = self.window else { return }
                    self.onWindow(window)
                }
                observations.append(obs)
            }
        }

        deinit {
            observations.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}
