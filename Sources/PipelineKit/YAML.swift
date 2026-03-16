import Foundation

// MARK: - YAML Parsing (minimal, purpose-built for pipeline configs)

/// Parse config.yaml: simple key-value pairs
public func parseRepoConfig(_ content: String) -> RepoConfig {
    var defaultPipeline = "default"
    for line in content.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        if let value = extractYAMLValue(trimmed, key: "default") {
            defaultPipeline = value
        }
    }
    return RepoConfig(defaultPipeline: defaultPipeline)
}

/// Serialize config.yaml
public func serializeRepoConfig(_ config: RepoConfig) -> String {
    "default: \(config.defaultPipeline)\n"
}

/// Parse pipeline.yaml
public func parsePipelineConfig(_ content: String) -> PipelineConfig {
    var name = ""
    var stages: [Stage] = []
    var settings = PipelineSettings()

    enum Section { case top, stages, stageItem, settings, variables }
    var section: Section = .top
    var currentStage: Stage?

    let lines = content.components(separatedBy: "\n")
    for line in lines {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        if stripped.isEmpty || stripped.hasPrefix("#") { continue }

        let indent = line.prefix(while: { $0 == " " }).count

        // Top-level keys (no indentation)
        if indent == 0 {
            // Finish any in-progress stage
            if let stage = currentStage {
                stages.append(stage)
                currentStage = nil
            }

            if let value = extractYAMLValue(stripped, key: "name") {
                name = value
                section = .top
            } else if stripped == "stages:" {
                section = .stages
            } else if stripped == "settings:" {
                section = .settings
            }
            continue
        }

        switch section {
        case .stages:
            // "  - name: Backlog" starts a new stage item
            if indent == 2 && stripped.hasPrefix("- ") {
                if let stage = currentStage {
                    stages.append(stage)
                }
                let afterDash = stripped.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if let value = extractYAMLValue(afterDash, key: "name") {
                    currentStage = Stage(name: value, type: .manual)
                    section = .stageItem
                }
            }
        case .stageItem:
            if indent >= 4 {
                if let value = extractYAMLValue(stripped, key: "type") {
                    currentStage?.type = StageType(rawValue: value) ?? .manual
                } else if let value = extractYAMLValue(stripped, key: "command") {
                    currentStage?.command = value
                }
            } else if indent == 2 && stripped.hasPrefix("- ") {
                // New stage item
                if let stage = currentStage {
                    stages.append(stage)
                }
                let afterDash = stripped.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if let value = extractYAMLValue(afterDash, key: "name") {
                    currentStage = Stage(name: value, type: .manual)
                }
            } else if indent == 0 {
                if let stage = currentStage {
                    stages.append(stage)
                    currentStage = nil
                }
                section = .top
            }
        case .settings:
            if indent >= 2 {
                if let value = extractYAMLValue(stripped, key: "pause_on_error") {
                    settings.pauseOnError = (value == "true")
                } else if let value = extractYAMLValue(stripped, key: "max_claims") {
                    settings.maxClaims = (value == "null") ? nil : Int(value)
                } else if stripped.hasPrefix("variables:") {
                    section = .variables
                }
            }
        case .variables:
            if indent >= 4 {
                // Parse variable key-value pairs
                if let colonIdx = stripped.firstIndex(of: ":") {
                    let key = String(stripped[stripped.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let val = String(stripped[stripped.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    settings.variables[key] = unquoteYAML(val)
                }
            } else {
                section = .settings
            }
        case .top:
            break
        }
    }

    // Finish last stage
    if let stage = currentStage {
        stages.append(stage)
    }

    return PipelineConfig(name: name, stages: stages, settings: settings)
}

/// Serialize pipeline.yaml
public func serializePipelineConfig(_ config: PipelineConfig) -> String {
    var lines: [String] = []
    lines.append("name: \"\(config.name)\"")
    lines.append("")
    lines.append("stages:")
    for stage in config.stages {
        lines.append("  - name: \(stage.name)")
        lines.append("    type: \(stage.type.rawValue)")
        if let command = stage.command {
            lines.append("    command: \"\(command)\"")
        }
    }
    lines.append("")
    lines.append("settings:")
    lines.append("  pause_on_error: \(config.settings.pauseOnError)")
    if let max = config.settings.maxClaims {
        lines.append("  max_claims: \(max)")
    } else {
        lines.append("  max_claims: null")
    }
    if config.settings.variables.isEmpty {
        lines.append("  variables: {}")
    } else {
        lines.append("  variables:")
        for (key, value) in config.settings.variables.sorted(by: { $0.key < $1.key }) {
            lines.append("    \(key): \"\(value)\"")
        }
    }
    return lines.joined(separator: "\n") + "\n"
}

// MARK: - Frontmatter Parsing

public struct Frontmatter {
    public var fields: [String: String] = [:]
    public var labels: [String] = []
    public var body: String = ""
}

/// Parse markdown with YAML frontmatter (between --- delimiters)
public func parseFrontmatter(_ content: String) -> Frontmatter {
    var fm = Frontmatter()
    let lines = content.components(separatedBy: "\n")

    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
        fm.body = content
        return fm
    }

    var inFrontmatter = true
    var frontmatterLines: [String] = []
    var bodyLines: [String] = []
    var foundClosing = false

    for (i, line) in lines.enumerated() {
        if i == 0 { continue } // skip opening ---
        if inFrontmatter {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontmatter = false
                foundClosing = true
                continue
            }
            frontmatterLines.append(line)
        } else {
            bodyLines.append(line)
        }
    }

    if !foundClosing {
        // No closing ---, treat entire content as body
        fm.body = content
        return fm
    }

    // Parse frontmatter key-value pairs
    for line in frontmatterLines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
        let key = String(trimmed[trimmed.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

        if key == "labels" {
            fm.labels = parseInlineArray(rawValue)
        } else {
            fm.fields[key] = unquoteYAML(rawValue)
        }
    }

    // Trim leading empty lines from body
    fm.body = bodyLines.joined(separator: "\n")
    while fm.body.hasPrefix("\n") {
        fm.body = String(fm.body.dropFirst())
    }

    return fm
}

/// Serialize a job file with frontmatter + body
public func serializeJob(title: String, priority: String? = nil, labels: [String] = [],
                         created: String? = nil, body: String) -> String {
    var lines: [String] = ["---"]
    lines.append("title: \(title)")
    if let priority = priority {
        lines.append("priority: \(priority)")
    }
    if !labels.isEmpty {
        lines.append("labels: [\(labels.joined(separator: ", "))]")
    }
    if let created = created {
        lines.append("created: \(created)")
    }
    lines.append("---")
    lines.append("")
    lines.append(body)
    return lines.joined(separator: "\n")
}

// MARK: - YAML Helpers

/// Extract value for a key from "key: value" or "key: \"value\""
func extractYAMLValue(_ line: String, key: String) -> String? {
    let prefix = key + ":"
    guard line.hasPrefix(prefix) else { return nil }
    let raw = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    return unquoteYAML(raw)
}

/// Remove surrounding quotes from a YAML value
func unquoteYAML(_ value: String) -> String {
    if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
       (value.hasPrefix("'") && value.hasSuffix("'")) {
        return String(value.dropFirst().dropLast())
    }
    return value
}

/// Parse inline YAML array: [a, b, c] → ["a", "b", "c"]
func parseInlineArray(_ value: String) -> [String] {
    var s = value.trimmingCharacters(in: .whitespaces)
    guard s.hasPrefix("[") && s.hasSuffix("]") else { return [] }
    s = String(s.dropFirst().dropLast())
    return s.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}
