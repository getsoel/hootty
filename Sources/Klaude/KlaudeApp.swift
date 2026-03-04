import SwiftUI
import KlaudeCore

@main
struct KlaudeApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        // Initialize the ghostty backend (singleton)
        _ = GhosttyApp.shared
    }

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
                .frame(minWidth: 700, minHeight: 400)
        }
        .commands {
            CommandMenu("View") {
                Button(appModel.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                    appModel.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Theme") {
                ForEach(CatppuccinFlavor.allCases, id: \.self) { flavor in
                    Button {
                        appModel.themeManager.selectedFlavor = flavor
                    } label: {
                        if appModel.themeManager.selectedFlavor == flavor {
                            Text("\(flavor.displayName) ✓")
                        } else {
                            Text(flavor.displayName)
                        }
                    }
                }
            }
        }
    }
}
