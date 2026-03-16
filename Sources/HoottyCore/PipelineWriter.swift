import Foundation

/// Pure-function utility for writing pipeline files to disk.
/// Counterpart to PipelineReader — handles mutations.
public enum PipelineWriter {
    /// Move a job markdown file from one stage directory to another.
    /// Returns true on success.
    public static func moveJob(repoRoot: String, pipelineName: String, jobSlug: String, fromStageDir: String, toStageDir: String) -> Bool {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        let fromDir = (pipelineDir as NSString).appendingPathComponent(fromStageDir)
        let toDir = (pipelineDir as NSString).appendingPathComponent(toStageDir)

        // Find the file in the source directory
        guard let files = try? fm.contentsOfDirectory(atPath: fromDir),
              let fileName = files.first(where: { $0.hasPrefix(jobSlug) && $0.hasSuffix(".md") }) else {
            return false
        }

        let sourcePath = (fromDir as NSString).appendingPathComponent(fileName)
        let destPath = (toDir as NSString).appendingPathComponent(fileName)

        // Ensure destination directory exists
        try? fm.createDirectory(atPath: toDir, withIntermediateDirectories: true)

        do {
            try fm.moveItem(atPath: sourcePath, toPath: destPath)
            return true
        } catch {
            return false
        }
    }

    /// Create a new job stub markdown file in a stage directory.
    /// Returns the slug on success, nil on failure.
    public static func addJob(repoRoot: String, pipelineName: String, title: String, stageDir: String, number: Int) -> String? {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        let targetDir = (pipelineDir as NSString).appendingPathComponent(stageDir)

        // Derive slug from title
        let slugBody = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .prefix(50)

        let slug = String(format: "%03d-%@", number, String(slugBody))
        let fileName = "\(slug).md"
        let filePath = (targetDir as NSString).appendingPathComponent(fileName)

        // Ensure directory exists
        try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        let content = """
        ---
        title: \(title)
        created: \(ISO8601DateFormatter().string(from: Date()))
        ---

        """

        guard let data = content.data(using: .utf8) else { return nil }
        if fm.createFile(atPath: filePath, contents: data) {
            return slug
        }
        return nil
    }

    /// Toggle the paused state for a pipeline in .state.json.
    /// Returns true on success.
    public static func togglePause(repoRoot: String, pipelineName: String) -> Bool {
        updateStateFile(repoRoot: repoRoot) { stateDict in
            guard var pipelineDict = stateDict[pipelineName] as? [String: Any] else { return }
            let currentPaused = pipelineDict["paused"] as? Bool ?? false
            pipelineDict["paused"] = !currentPaused
            stateDict[pipelineName] = pipelineDict
        }
    }

    /// Remove a job markdown file from a stage directory.
    /// Returns true if the file was found and removed.
    public static func removeJob(repoRoot: String, pipelineName: String, jobSlug: String, stageDir: String) -> Bool {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        let dir = (pipelineDir as NSString).appendingPathComponent(stageDir)

        guard let files = try? fm.contentsOfDirectory(atPath: dir),
              let fileName = files.first(where: { $0.hasPrefix(jobSlug) && $0.hasSuffix(".md") }) else {
            return false
        }

        let filePath = (dir as NSString).appendingPathComponent(fileName)
        do {
            try fm.removeItem(atPath: filePath)
            return true
        } catch {
            return false
        }
    }

    /// Append a timestamped log entry to the ## Log section of a job file.
    public static func appendLogEntry(repoRoot: String, pipelineName: String, jobSlug: String, stages: [PipelineStageDef], message: String) -> Bool {
        guard let result = PipelineReader.findJobFilePath(repoRoot: repoRoot, pipelineName: pipelineName, stages: stages, jobSlug: jobSlug),
              let data = FileManager.default.contents(atPath: result.path),
              var content = String(data: data, encoding: .utf8) else { return false }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "- \(timestamp) — \(message)"

        if let logRange = content.range(of: "## Log\n") {
            content.insert(contentsOf: logEntry + "\n", at: logRange.upperBound)
        } else {
            content += "\n\n## Log\n\(logEntry)\n"
        }

        return FileManager.default.createFile(atPath: result.path, contents: content.data(using: .utf8))
    }

    /// Update the title field in a job file's YAML frontmatter.
    public static func updateJobTitle(repoRoot: String, pipelineName: String, jobSlug: String, stages: [PipelineStageDef], newTitle: String) -> Bool {
        guard let result = PipelineReader.findJobFilePath(repoRoot: repoRoot, pipelineName: pipelineName, stages: stages, jobSlug: jobSlug),
              let data = FileManager.default.contents(atPath: result.path),
              let content = String(data: data, encoding: .utf8) else { return false }

        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        var newLines: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontmatter.toggle()
                newLines.append(line)
                continue
            }
            if inFrontmatter, line.trimmingCharacters(in: .whitespaces).hasPrefix("title:") {
                newLines.append("title: \(newTitle)")
            } else {
                newLines.append(line)
            }
        }
        let updated = newLines.joined(separator: "\n")
        return FileManager.default.createFile(atPath: result.path, contents: updated.data(using: .utf8))
    }

    /// Create a new pipeline with config and stage directories.
    public static func createPipeline(repoRoot: String, pipelineName: String, displayName: String, stages: [PipelineStageDef]) -> Bool {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")

        do {
            try fm.createDirectory(atPath: pipelineDir, withIntermediateDirectories: true)
        } catch {
            return false
        }

        guard writePipelineYAML(at: pipelineDir, displayName: displayName, stages: stages) else {
            return false
        }

        for stage in stages {
            let stageDir = (pipelineDir as NSString).appendingPathComponent(stage.name.lowercased())
            try? fm.createDirectory(atPath: stageDir, withIntermediateDirectories: true)
        }

        return ensureStateEntry(repoRoot: repoRoot, pipelineName: pipelineName)
    }

    /// Delete a pipeline directory entirely.
    public static func deletePipeline(repoRoot: String, pipelineName: String) -> Bool {
        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        do {
            try fm.removeItem(atPath: pipelineDir)
            return removeStateEntry(repoRoot: repoRoot, pipelineName: pipelineName)
        } catch {
            return false
        }
    }

    /// Add a stage to a pipeline's pipeline.yaml and create the directory.
    public static func addStage(repoRoot: String, pipelineName: String, stageName: String, type: PipelineStageDef.StageType, afterIndex: Int?) -> Bool {
        guard let config = PipelineReader.readPipelineConfig(repoRoot: repoRoot, pipelineName: pipelineName) else { return false }

        var stages = config.stages
        let newStage = PipelineStageDef(name: stageName, type: type)
        let insertIndex = (afterIndex ?? stages.count - 1) + 1
        stages.insert(newStage, at: min(insertIndex, stages.count))

        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        let stageDir = (pipelineDir as NSString).appendingPathComponent(stageName.lowercased())
        try? FileManager.default.createDirectory(atPath: stageDir, withIntermediateDirectories: true)

        return writePipelineYAML(at: pipelineDir, displayName: config.name, stages: stages)
    }

    /// Remove a stage from a pipeline. Moves jobs to previous stage.
    public static func removeStage(repoRoot: String, pipelineName: String, stageIndex: Int) -> Bool {
        guard let config = PipelineReader.readPipelineConfig(repoRoot: repoRoot, pipelineName: pipelineName) else { return false }
        guard stageIndex >= 0, stageIndex < config.stages.count, config.stages.count > 1 else { return false }

        let removedStage = config.stages[stageIndex]
        let targetIndex = max(0, stageIndex - 1)
        let targetStage = config.stages[stageIndex == 0 ? 1 : targetIndex]

        let fm = FileManager.default
        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        let removedDir = (pipelineDir as NSString).appendingPathComponent(removedStage.name.lowercased())
        let targetDir = (pipelineDir as NSString).appendingPathComponent(targetStage.name.lowercased())

        if let files = try? fm.contentsOfDirectory(atPath: removedDir) {
            for file in files where file.hasSuffix(".md") {
                let src = (removedDir as NSString).appendingPathComponent(file)
                let dst = (targetDir as NSString).appendingPathComponent(file)
                try? fm.moveItem(atPath: src, toPath: dst)
            }
        }
        try? fm.removeItem(atPath: removedDir)

        var stages = config.stages
        stages.remove(at: stageIndex)
        return writePipelineYAML(at: pipelineDir, displayName: config.name, stages: stages)
    }

    /// Change a stage's type (automated/manual).
    public static func changeStageType(repoRoot: String, pipelineName: String, stageIndex: Int, newType: PipelineStageDef.StageType) -> Bool {
        guard let config = PipelineReader.readPipelineConfig(repoRoot: repoRoot, pipelineName: pipelineName) else { return false }
        guard stageIndex >= 0, stageIndex < config.stages.count else { return false }

        var stages = config.stages
        let old = stages[stageIndex]
        stages[stageIndex] = PipelineStageDef(name: old.name, type: newType, command: old.command)

        let pipelineDir = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/\(pipelineName)")
        return writePipelineYAML(at: pipelineDir, displayName: config.name, stages: stages)
    }

    /// Write pipeline.yaml to a pipeline directory.
    private static func writePipelineYAML(at pipelineDir: String, displayName: String, stages: [PipelineStageDef]) -> Bool {
        var yaml = "name: \"\(displayName)\"\n\nstages:\n"
        for stage in stages {
            yaml += "  - name: \(stage.name)\n"
            yaml += "    type: \(stage.type.rawValue)\n"
            if let command = stage.command {
                yaml += "    command: \"\(command)\"\n"
            }
        }
        let filePath = (pipelineDir as NSString).appendingPathComponent("pipeline.yaml")
        return FileManager.default.createFile(atPath: filePath, contents: yaml.data(using: .utf8))
    }

    /// Ensure .state.json has an entry for a pipeline.
    private static func ensureStateEntry(repoRoot: String, pipelineName: String) -> Bool {
        updateStateFile(repoRoot: repoRoot) { stateDict in
            if stateDict[pipelineName] == nil {
                stateDict[pipelineName] = [
                    "claims": [:] as [String: String],
                    "job_statuses": [:] as [String: String],
                    "paused": false
                ] as [String: Any]
            }
        }
    }

    /// Remove a pipeline's entry from .state.json.
    private static func removeStateEntry(repoRoot: String, pipelineName: String) -> Bool {
        updateStateFile(repoRoot: repoRoot) { stateDict in
            stateDict.removeValue(forKey: pipelineName)
        }
    }

    // MARK: - State File Helpers

    /// Read-modify-write .state.json. The update closure receives a mutable dictionary
    /// of pipeline name -> pipeline state. Returns true on success.
    private static func updateStateFile(repoRoot: String, update: (inout [String: Any]) -> Void) -> Bool {
        let path = (repoRoot as NSString).appendingPathComponent("\(PipelineReader.directoryPath)/.state.json")
        let fm = FileManager.default

        // Read existing state
        var root: [String: Any] = [:]
        if let data = fm.contents(atPath: path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = json
        }

        var pipelines = root["pipelines"] as? [String: Any] ?? [:]
        update(&pipelines)
        root["pipelines"] = pipelines

        // Write back
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }
        return fm.createFile(atPath: path, contents: data)
    }
}
