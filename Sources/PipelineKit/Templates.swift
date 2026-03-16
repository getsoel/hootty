import Foundation

public enum PipelineTemplate: String, CaseIterable {
    case simple
    case review
    case fullCi = "full-ci"

    public var config: PipelineConfig {
        switch self {
        case .simple:
            PipelineConfig(
                name: "Pipeline",
                stages: [
                    Stage(name: "Backlog", type: .manual),
                    Stage(name: "Run", type: .automated),
                    Stage(name: "Done", type: .manual)
                ]
            )
        case .review:
            PipelineConfig(
                name: "Pipeline",
                stages: [
                    Stage(name: "Backlog", type: .manual),
                    Stage(name: "Implement", type: .automated),
                    Stage(name: "Review", type: .manual),
                    Stage(name: "Done", type: .manual)
                ]
            )
        case .fullCi:
            PipelineConfig(
                name: "Pipeline",
                stages: [
                    Stage(name: "Backlog", type: .manual),
                    Stage(name: "Implement", type: .automated),
                    Stage(name: "Review", type: .manual),
                    Stage(name: "Test", type: .automated, command: "Write tests for the changes you just made. Run them and fix any failures."),
                    Stage(name: "Commit", type: .automated, command: "/commit"),
                    Stage(name: "Done", type: .manual)
                ]
            )
        }
    }
}
