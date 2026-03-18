import Foundation

/// Reads macro definitions from `.hootty/macros/` directories.
/// Scans the focused pane's repo root for YAML macro files.
@MainActor
@Observable
public final class MacroStore {
    public private(set) var macros: [Macro] = []

    public init() {}

    /// Directory name within repo root where macros are stored.
    public static let directoryPath = ".hootty/macros"

    /// Check if a repo has a macros directory.
    public nonisolated static func hasMacros(repoRoot: String) -> Bool {
        var isDir: ObjCBool = false
        let path = (repoRoot as NSString).appendingPathComponent(directoryPath)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Scan `.hootty/macros/` in the given repo root for YAML macro files.
    public func refresh(repoRoot: String) {
        let dir = (repoRoot as NSString).appendingPathComponent(Self.directoryPath)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else {
            macros = []
            return
        }

        var result: [Macro] = []
        for file in files.sorted() {
            guard file.hasSuffix(".yaml") || file.hasSuffix(".yml") else { continue }
            let path = (dir as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8),
                  let parsed = parseMacroFile(content) else { continue }
            let stem = (file as NSString).deletingPathExtension
            result.append(Macro(id: stem, name: parsed.name, steps: parsed.steps))
        }
        macros = result
    }
}
