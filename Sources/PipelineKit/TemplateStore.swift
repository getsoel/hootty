import Foundation

/// Manages pipeline templates stored as YAML files in a global directory.
/// Default templates are seeded from built-in `PipelineTemplate` cases.
public class TemplateStore {
    public let rootPath: String

    public init(rootPath: String) {
        self.rootPath = rootPath
    }

    /// Default global directory: ~/Library/Application Support/Hootty/pipeline-templates/
    public static var defaultDirectory: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #if DEBUG
            let dir = appSupport.appendingPathComponent("Hootty-Dev", isDirectory: true)
        #else
            let dir = appSupport.appendingPathComponent("Hootty", isDirectory: true)
        #endif
        return dir.appendingPathComponent("pipeline-templates").path
    }

    /// Seed default templates if the directory has no templates yet.
    public func seedDefaults() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: rootPath) {
            try? fm.createDirectory(atPath: rootPath, withIntermediateDirectories: true)
        }
        if listTemplates().isEmpty {
            for template in PipelineTemplate.allCases {
                try? saveTemplate(name: template.rawValue, config: template.config)
            }
        }
    }

    /// List available template names (sorted).
    public func listTemplates() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: rootPath) else { return [] }
        return entries
            .filter { $0.hasSuffix(".yaml") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()
    }

    /// Load a template config by name.
    public func loadTemplate(name: String) throws -> PipelineConfig {
        let path = templatePath(name: name)
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            throw PipelineError.unknownTemplate(name)
        }
        return parsePipelineConfig(content)
    }

    /// Save a template.
    public func saveTemplate(name: String, config: PipelineConfig) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: rootPath) {
            try fm.createDirectory(atPath: rootPath, withIntermediateDirectories: true)
        }
        try serializePipelineConfig(config).write(toFile: templatePath(name: name), atomically: true, encoding: .utf8)
    }

    /// Delete a template.
    public func deleteTemplate(name: String) throws {
        let path = templatePath(name: name)
        guard FileManager.default.fileExists(atPath: path) else {
            throw PipelineError.unknownTemplate(name)
        }
        try FileManager.default.removeItem(atPath: path)
    }

    /// File path for a template.
    public func templatePath(name: String) -> String {
        (rootPath as NSString).appendingPathComponent("\(name).yaml")
    }
}
