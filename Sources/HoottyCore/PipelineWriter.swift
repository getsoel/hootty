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
