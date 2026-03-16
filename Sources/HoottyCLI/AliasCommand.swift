import Foundation

private let marker = "# Added by hootty alias"
private let aliases: [(name: String, expansion: String)] = [
    ("pipeline", "hootty pipeline"),
]

func handleAlias(_ args: [String]) throws {
    let command = args.first ?? "install"

    switch command {
    case "install":
        try installAliases()
    case "remove":
        try removeAliases()
    case "status":
        printAliasStatus()
    case "help", "--help", "-h":
        printAliasUsage()
    default:
        printError("Unknown alias subcommand: \(command)")
        printAliasUsage()
        exit(1)
    }
}

// MARK: - Install

private func installAliases() throws {
    let rcPath = shellRCPath()
    let rcFile = (rcPath as NSString).lastPathComponent

    // Read existing content
    let existing = (try? String(contentsOfFile: rcPath, encoding: .utf8)) ?? ""

    if existing.contains(marker) {
        print("Aliases already installed in ~/\(rcFile). Run `hootty alias remove` first to reinstall.")
        return
    }

    let block = buildAliasBlock()
    let separator = existing.hasSuffix("\n") || existing.isEmpty ? "\n" : "\n\n"
    let updated = existing + separator + block + "\n"

    try updated.write(toFile: rcPath, atomically: true, encoding: .utf8)

    print("Installed aliases in ~/\(rcFile):")
    for alias in aliases {
        print("  \(alias.name) → \(alias.expansion)")
    }
    print("\nRun `source ~/\(rcFile)` or open a new terminal to activate.")
}

// MARK: - Remove

private func removeAliases() throws {
    let rcPath = shellRCPath()
    let rcFile = (rcPath as NSString).lastPathComponent

    guard let existing = try? String(contentsOfFile: rcPath, encoding: .utf8) else {
        print("No ~/\(rcFile) found.")
        return
    }

    guard existing.contains(marker) else {
        print("No hootty aliases found in ~/\(rcFile).")
        return
    }

    let lines = existing.components(separatedBy: "\n")
    var filtered: [String] = []
    var inBlock = false

    for line in lines {
        if line.hasPrefix(marker) {
            inBlock = true
            continue
        }
        if inBlock {
            // Skip alias lines and the trailing empty line
            if line.hasPrefix("alias ") || line.isEmpty {
                if line.isEmpty { inBlock = false }
                continue
            }
            inBlock = false
        }
        filtered.append(line)
    }

    // Trim trailing blank lines
    while filtered.last == "" && filtered.count > 1 {
        filtered.removeLast()
    }

    try (filtered.joined(separator: "\n") + "\n").write(toFile: rcPath, atomically: true, encoding: .utf8)
    print("Removed hootty aliases from ~/\(rcFile).")
}

// MARK: - Status

private func printAliasStatus() {
    let rcPath = shellRCPath()
    let rcFile = (rcPath as NSString).lastPathComponent
    let existing = (try? String(contentsOfFile: rcPath, encoding: .utf8)) ?? ""

    if existing.contains(marker) {
        print("Aliases installed in ~/\(rcFile):")
        for alias in aliases {
            print("  \(alias.name) → \(alias.expansion)")
        }
    } else {
        print("No hootty aliases installed. Run `hootty alias install` to set up.")
    }
}

// MARK: - Helpers

private func shellRCPath() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

    if shell.hasSuffix("/bash") {
        // Prefer .bash_profile on macOS (login shell), fall back to .bashrc
        let profile = (home as NSString).appendingPathComponent(".bash_profile")
        if FileManager.default.fileExists(atPath: profile) {
            return profile
        }
        return (home as NSString).appendingPathComponent(".bashrc")
    }

    // Default to zsh
    return (home as NSString).appendingPathComponent(".zshrc")
}

private func buildAliasBlock() -> String {
    var lines = [marker]
    for alias in aliases {
        lines.append("alias \(alias.name)='\(alias.expansion)'")
    }
    return lines.joined(separator: "\n")
}

private func printAliasUsage() {
    print("""
    hootty alias — manage shell aliases for hootty subcommands

    Usage: hootty alias <install|remove|status>

    Commands:
      install     Add aliases to your shell config (~/.zshrc or ~/.bashrc)
      remove      Remove aliases from your shell config
      status      Show whether aliases are installed

    Aliases created:
      pipeline → hootty pipeline
    """)
}
