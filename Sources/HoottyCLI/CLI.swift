import Foundation
import PipelineKit

@main
struct HoottyCLI {
    static func main() {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            guard let command = args.first else {
                printTopLevelUsage()
                exit(0)
            }
            let remaining = Array(args.dropFirst())

            switch command {
            case "pipeline":
                try handlePipelineCommand(remaining)
            case "alias":
                try handleAlias(remaining)
            case "help", "--help", "-h":
                printTopLevelUsage()
            case "version", "--version":
                print("hootty 0.1.0")
            default:
                printError("Unknown command: \(command)")
                printTopLevelUsage()
                exit(1)
            }
        } catch let error as PipelineError {
            printError(error.description)
            exit(1)
        } catch {
            printError(error.localizedDescription)
            exit(1)
        }
    }
}

// MARK: - Argument Parsing

struct Flags {
    var named: [String: String] = [:]
    var booleans: Set<String> = []
    var positional: [String] = []

    init(_ args: [String]) {
        var i = 0
        while i < args.count {
            if args[i].hasPrefix("--") {
                let flag = String(args[i].dropFirst(2))
                if i + 1 < args.count && !args[i + 1].hasPrefix("--") {
                    named[flag] = args[i + 1]
                    i += 2
                } else {
                    booleans.insert(flag)
                    i += 1
                }
            } else {
                positional.append(args[i])
                i += 1
            }
        }
    }

    func has(_ name: String) -> Bool { booleans.contains(name) }
    func get(_ name: String) -> String? { named[name] }
}

// MARK: - Helpers

func printError(_ message: String) {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
}

func printTopLevelUsage() {
    print("""
    hootty — CLI tools for Hootty terminal emulator

    Usage: hootty <command> [options]

    Commands:
      pipeline    Manage pipelines, jobs, claims, and stages
      alias       Install/remove shell aliases (e.g. `pipeline` → `hootty pipeline`)
      version     Show version
      help        Show this help

    Run `hootty <command> help` for details on a specific command.
    """)
}
