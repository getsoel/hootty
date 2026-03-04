import Foundation

@Observable
public final class ThemeManager {
    private static let defaultsKey = "selectedTheme"

    public var selectedFlavor: CatppuccinFlavor {
        didSet {
            UserDefaults.standard.set(selectedFlavor.rawValue, forKey: Self.defaultsKey)
            theme = .catppuccin(selectedFlavor)
        }
    }

    public private(set) var theme: TerminalTheme

    public init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(CatppuccinFlavor.init(rawValue:)) ?? .mocha
        self.selectedFlavor = saved
        self.theme = .catppuccin(saved)
    }
}
