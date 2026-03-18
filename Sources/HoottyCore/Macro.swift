import Foundation
import PipelineKit

/// A macro definition: a named sequence of steps to execute in a Claude Code session.
public struct Macro: Identifiable, Sendable {
    public let id: String // filename stem, e.g. "review-flow"
    public let name: String
    public let steps: [String]

    public init(id: String, name: String, steps: [String]) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}

/// Parse a macro YAML file. Expected format:
/// ```
/// name: Review Flow
/// steps:
///   - /simplify
///   - /reflect
///   - "Check for TODO comments"
/// ```
public func parseMacroFile(_ content: String) -> (name: String, steps: [String])? {
    var name = ""
    var steps: [String] = []
    var inSteps = false

    for line in content.components(separatedBy: "\n") {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        if stripped.isEmpty || stripped.hasPrefix("#") { continue }

        let indent = line.prefix(while: { $0 == " " }).count

        if indent == 0 {
            if stripped == "steps:" {
                inSteps = true
                continue
            }
            inSteps = false
            if let value = extractYAMLValue(stripped, key: "name") {
                name = value
            }
        } else if inSteps, indent >= 2, stripped.hasPrefix("- ") {
            let value = stripped.dropFirst(2).trimmingCharacters(in: .whitespaces)
            steps.append(unquoteYAML(value))
        }
    }

    guard !name.isEmpty, !steps.isEmpty else { return nil }
    return (name, steps)
}
