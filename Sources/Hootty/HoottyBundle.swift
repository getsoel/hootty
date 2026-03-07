import Foundation

enum HoottyBundle {
    static let resourceBundle: Bundle? = {
        let bundleName = "Hootty_Hootty"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
        ]
        for candidate in candidates {
            if let candidate, let bundle = Bundle(url: candidate),
               bundle.resourceURL != nil {
                return bundle
            }
            let nested = candidate?.appendingPathComponent("\(bundleName).bundle")
            if let nested, let bundle = Bundle(url: nested) {
                return bundle
            }
        }
        // Fallback: look next to the executable
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let siblingBundle = execURL.deletingLastPathComponent()
            .appendingPathComponent("\(bundleName).bundle")
        if let bundle = Bundle(url: siblingBundle) {
            return bundle
        }
        return nil
    }()
}
