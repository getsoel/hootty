import Foundation

/// Pure-function utility for reading pipeline files from disk.
/// No state, no @Observable — just file I/O and parsing.
public enum PipelineReader {
    /// Relative path from repo root to the pipeline directory.
    public static let directoryPath = ".hootty/pipeline"

    /// Check whether a pipeline directory exists at the given repo root.
    public static func hasPipeline(repoRoot: String) -> Bool {
        var isDir: ObjCBool = false
        let path = (repoRoot as NSString).appendingPathComponent(directoryPath)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Read and decode `.state.json` from the pipeline directory.
    public static func readStateFile(repoRoot: String) -> PipelineStateFile? {
        let path = (repoRoot as NSString).appendingPathComponent("\(directoryPath)/.state.json")
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(PipelineStateFile.self, from: data)
    }

    /// Read and parse `<pipelineName>/pipeline.yaml` from the pipeline directory.
    public static func readPipelineConfig(repoRoot: String, pipelineName: String) -> PipelineConfig? {
        let path = (repoRoot as NSString)
            .appendingPathComponent("\(directoryPath)/\(pipelineName)/pipeline.yaml")
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return nil }
        return parsePipelineYAML(content)
    }

    /// Find which stage directory contains a job file matching the given slug.
    public static func findJobStage(repoRoot: String, pipelineName: String, stages: [PipelineStageDef], jobSlug: String) -> Int? {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(directoryPath)/\(pipelineName)")

        for (index, stage) in stages.enumerated() {
            let stageDir = (pipelineDir as NSString).appendingPathComponent(stage.name.lowercased())
            guard let files = try? fm.contentsOfDirectory(atPath: stageDir) else { continue }
            if files.contains(where: { $0.hasPrefix(jobSlug) && $0.hasSuffix(".md") }) {
                return index
            }
        }
        return nil
    }

    /// Read the `title` field from a job markdown file's YAML frontmatter.
    public static func readJobTitle(repoRoot: String, pipelineName: String, stages: [PipelineStageDef], jobSlug: String) -> String? {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(directoryPath)/\(pipelineName)")

        for stage in stages {
            let stageDir = (pipelineDir as NSString).appendingPathComponent(stage.name.lowercased())
            guard let files = try? fm.contentsOfDirectory(atPath: stageDir) else { continue }
            guard let fileName = files.first(where: { $0.hasPrefix(jobSlug) && $0.hasSuffix(".md") }) else { continue }
            let filePath = (stageDir as NSString).appendingPathComponent(fileName)
            guard let data = fm.contents(atPath: filePath),
                  let content = String(data: data, encoding: .utf8) else { continue }
            return parseFrontmatterTitle(content)
        }
        return nil
    }

    /// Search all pipeline claims for a session key matching any of the provided identifiers.
    /// Returns (pipelineName, jobSlug) if found.
    public static func resolveClaimForSession(stateFile: PipelineStateFile, sessionIDs: [String]) -> (pipelineName: String, jobSlug: String)? {
        for (pipelineName, runtime) in stateFile.pipelines {
            for (sessionKey, jobSlug) in runtime.claims where sessionIDs.contains(sessionKey) {
                return (pipelineName, jobSlug)
            }
        }
        return nil
    }

    /// Parsed frontmatter fields from a job markdown file.
    public struct JobFrontmatter: Sendable {
        public let title: String?
        public let priority: String?
        public let labels: [String]
    }

    /// A job file entry discovered by scanning stage directories.
    public struct JobEntry: Sendable {
        public let slug: String
        public let title: String
        public let stageIndex: Int
        public let priority: String?
        public let labels: [String]
    }

    /// Read all jobs across all stage directories for a pipeline.
    public static func readAllJobs(repoRoot: String, pipelineName: String, stages: [PipelineStageDef]) -> [JobEntry] {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(directoryPath)/\(pipelineName)")
        var results: [JobEntry] = []

        for (index, stage) in stages.enumerated() {
            let stageDir = (pipelineDir as NSString).appendingPathComponent(stage.name.lowercased())
            guard let files = try? fm.contentsOfDirectory(atPath: stageDir) else { continue }
            for file in files.sorted() where file.hasSuffix(".md") {
                let slug = String(file.dropLast(3)) // remove .md
                let filePath = (stageDir as NSString).appendingPathComponent(file)
                let meta = parseFrontmatterFromFile(filePath)
                let title = meta?.title ?? slug
                results.append(JobEntry(slug: slug, title: title, stageIndex: index, priority: meta?.priority, labels: meta?.labels ?? []))
            }
        }
        return results
    }

    /// Read the markdown body (after frontmatter) of a job file.
    public static func readJobBody(repoRoot: String, pipelineName: String, stages: [PipelineStageDef], jobSlug: String) -> String? {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(directoryPath)/\(pipelineName)")

        for stage in stages {
            let stageDir = (pipelineDir as NSString).appendingPathComponent(stage.name.lowercased())
            guard let files = try? fm.contentsOfDirectory(atPath: stageDir) else { continue }
            guard let fileName = files.first(where: { $0.hasPrefix(jobSlug) && $0.hasSuffix(".md") }) else { continue }
            let filePath = (stageDir as NSString).appendingPathComponent(fileName)
            guard let data = fm.contents(atPath: filePath),
                  let content = String(data: data, encoding: .utf8) else { continue }
            return extractBodyAfterFrontmatter(content)
        }
        return nil
    }

    /// List all pipeline directories in the repo (for multi-pipeline support).
    public static func listPipelines(repoRoot: String) -> [String] {
        let fm = FileManager.default
        let pipelineBase = (repoRoot as NSString).appendingPathComponent(directoryPath)
        guard let entries = try? fm.contentsOfDirectory(atPath: pipelineBase) else { return [] }
        return entries.filter { name in
            guard !name.hasPrefix(".") else { return false }
            let subdir = (pipelineBase as NSString).appendingPathComponent(name)
            let configPath = (subdir as NSString).appendingPathComponent("pipeline.yaml")
            return fm.fileExists(atPath: configPath)
        }.sorted()
    }

    /// Find the next available job number across all stages in a pipeline.
    public static func nextJobNumber(repoRoot: String, pipelineName: String, stages: [PipelineStageDef]) -> Int {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(directoryPath)/\(pipelineName)")
        var maxNum = 0

        for stage in stages {
            let stageDir = (pipelineDir as NSString).appendingPathComponent(stage.name.lowercased())
            guard let files = try? fm.contentsOfDirectory(atPath: stageDir) else { continue }
            for file in files where file.hasSuffix(".md") {
                // Extract leading digits from filename
                let digits = file.prefix(while: { $0.isNumber })
                if let num = Int(digits) {
                    maxNum = max(maxNum, num)
                }
            }
        }
        return maxNum + 1
    }

    // MARK: - Minimal YAML Parser

    /// Parse the specific pipeline.yaml format:
    /// ```
    /// name: "Pipeline Name"
    /// stages:
    ///   - name: StageName
    ///     type: manual
    /// ```
    private static func parsePipelineYAML(_ content: String) -> PipelineConfig? {
        let lines = content.components(separatedBy: .newlines)
        var configName: String?
        var stages: [PipelineStageDef] = []
        var inStages = false
        var currentStageName: String?
        var currentStageType: PipelineStageDef.StageType?
        var currentStageCommand: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Top-level name
            if !inStages, trimmed.hasPrefix("name:") {
                configName = extractYAMLValue(trimmed, key: "name")
                continue
            }

            // Stages list start
            if trimmed == "stages:" {
                inStages = true
                continue
            }

            // Settings block or other top-level key ends stages
            if inStages, !line.hasPrefix(" "), !line.hasPrefix("\t") {
                // Flush last stage
                if let name = currentStageName {
                    stages.append(PipelineStageDef(name: name, type: currentStageType ?? .manual, command: currentStageCommand))
                    currentStageName = nil
                    currentStageType = nil
                    currentStageCommand = nil
                }
                inStages = false
                continue
            }

            if inStages {
                // New list item: "  - name: Foo"
                if trimmed.hasPrefix("- name:") {
                    // Flush previous stage
                    if let name = currentStageName {
                        stages.append(PipelineStageDef(name: name, type: currentStageType ?? .manual, command: currentStageCommand))
                    }
                    currentStageName = extractYAMLValue(trimmed, key: "- name")
                    currentStageType = nil
                    currentStageCommand = nil
                } else if trimmed.hasPrefix("type:") {
                    currentStageType = PipelineStageDef.StageType(rawValue: extractYAMLValue(trimmed, key: "type")?.lowercased() ?? "manual")
                } else if trimmed.hasPrefix("command:") {
                    currentStageCommand = extractYAMLValue(trimmed, key: "command")
                }
            }
        }

        // Flush last stage
        if let name = currentStageName {
            stages.append(PipelineStageDef(name: name, type: currentStageType ?? .manual, command: currentStageCommand))
        }

        guard let name = configName, !stages.isEmpty else { return nil }
        return PipelineConfig(name: name, stages: stages)
    }

    private static func extractYAMLValue(_ line: String, key: String) -> String? {
        guard let colonRange = line.range(of: "\(key):") else { return nil }
        let raw = line[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
        // Strip surrounding quotes
        if (raw.hasPrefix("\"") && raw.hasSuffix("\"")) || (raw.hasPrefix("'") && raw.hasSuffix("'")) {
            return String(raw.dropFirst().dropLast())
        }
        return raw.isEmpty ? nil : raw
    }

    // MARK: - Frontmatter Parser

    private static func parseFrontmatterTitle(_ content: String) -> String? {
        parseFrontmatter(content)?.title
    }

    /// Parse all supported frontmatter fields from a job markdown file.
    static func parseFrontmatter(_ content: String) -> JobFrontmatter? {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var title: String?
        var priority: String?
        var labels: [String] = []

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }

            if trimmed.hasPrefix("title:") {
                title = extractYAMLValue(trimmed, key: "title")
            } else if trimmed.hasPrefix("priority:") {
                priority = extractYAMLValue(trimmed, key: "priority")?.lowercased()
            } else if trimmed.hasPrefix("labels:") {
                if let raw = extractYAMLValue(trimmed, key: "labels") {
                    // Parse inline list: "auth, refactor" or "[auth, refactor]"
                    let cleaned = raw.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    labels = cleaned.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            }
        }
        return JobFrontmatter(title: title, priority: priority, labels: labels)
    }

    /// Parse frontmatter from a file path.
    private static func parseFrontmatterFromFile(_ path: String) -> JobFrontmatter? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return nil }
        return parseFrontmatter(content)
    }

    /// Extract the body content after YAML frontmatter.
    private static func extractBodyAfterFrontmatter(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content
        }

        var foundEnd = false
        var bodyLines: [String] = []
        for line in lines.dropFirst() {
            if !foundEnd {
                if line.trimmingCharacters(in: .whitespaces) == "---" {
                    foundEnd = true
                }
                continue
            }
            bodyLines.append(line)
        }

        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }
}
