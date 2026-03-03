import SwiftUI

@main
struct KlaudeApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    @State private var sessions: [Session] = [Session(name: "Session 1")]

    var body: some Scene {
        WindowGroup {
            ContentView(sessions: $sessions)
                .frame(minWidth: 700, minHeight: 400)
        }
    }
}
