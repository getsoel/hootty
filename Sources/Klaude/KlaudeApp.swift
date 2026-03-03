import SwiftUI

@main
struct KlaudeApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
                .frame(minWidth: 700, minHeight: 400)
        }
        .commands {
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
