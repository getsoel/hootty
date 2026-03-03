import Foundation

@Observable
final class ThemeManager {
    var selectedFlavor: CatppuccinFlavor {
        didSet {
            UserDefaults.standard.set(selectedFlavor.rawValue, forKey: "selectedTheme")
            theme = TerminalTheme.catppuccin(selectedFlavor)
        }
    }

    private(set) var theme: TerminalTheme

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTheme")
            .flatMap(CatppuccinFlavor.init(rawValue:)) ?? .mocha
        self.selectedFlavor = saved
        self.theme = TerminalTheme.catppuccin(saved)
    }
}
