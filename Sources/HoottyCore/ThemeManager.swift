import Foundation

@Observable
public final class ThemeManager {
    private static let defaultsKey = "selectedTheme"

    #if DEBUG
    private static let defaults = UserDefaults(suiteName: "com.soel.hootty-dev")!
    #else
    private static let defaults = UserDefaults.standard
    #endif

    public var selectedFlavor: CatppuccinFlavor {
        didSet {
            Self.defaults.set(selectedFlavor.rawValue, forKey: Self.defaultsKey)
            theme = .catppuccin(selectedFlavor)
        }
    }

    public private(set) var theme: TerminalTheme

    public init() {
        let saved = Self.defaults.string(forKey: Self.defaultsKey)
            .flatMap(CatppuccinFlavor.init(rawValue:)) ?? .mocha
        self.selectedFlavor = saved
        self.theme = .catppuccin(saved)
    }
}
