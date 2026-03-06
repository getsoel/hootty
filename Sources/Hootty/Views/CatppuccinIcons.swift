import SwiftUI
import HoottyCore
import LucideIcons

struct CatppuccinIconView: View {
    let name: String
    let size: CGFloat
    let flavor: CatppuccinFlavor

    var body: some View {
        if let image = Self.loadImage(name: name, flavor: flavor) {
            Image(nsImage: image)
                .frame(width: size, height: size)
        } else {
            LucideIcon(Lucide.circleQuestionMark, size: size)
                .foregroundStyle(.secondary)
        }
    }

    private static let resourceBundle: Bundle? = {
        let bundleName = "Hootty_Hootty"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
        ]
        for candidate in candidates {
            if let bundle = Bundle(url: candidate ?? URL(fileURLWithPath: "/")),
               bundle.url(forResource: "Icons", withExtension: nil) != nil {
                return bundle
            }
            let nested = candidate?.appendingPathComponent("\(bundleName).bundle")
            if let nested, let bundle = Bundle(url: nested),
               bundle.url(forResource: "Icons", withExtension: nil) != nil {
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

    private static let imageCache = NSCache<NSString, NSImage>()

    private static func loadImage(name: String, flavor: CatppuccinFlavor) -> NSImage? {
        let key = "\(flavor.rawValue)/\(name)" as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let bundle = resourceBundle else { return nil }
        guard let url = bundle.url(
            forResource: name,
            withExtension: "svg",
            subdirectory: "Icons/\(flavor.rawValue)"
        ) else { return nil }
        guard let image = NSImage(contentsOf: url) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }
}
