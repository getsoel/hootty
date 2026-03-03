import Foundation

struct PTYProcess {
    let masterFD: Int32
    let pid: pid_t

    /// Spawns a child process in a new PTY.
    /// All Swift string → C conversions happen BEFORE fork.
    /// The child only calls async-signal-safe functions (chdir, execve).
    static func spawn(
        command: String = "/bin/zsh",
        arguments: [String] = ["--login"],
        environment: [String: String]? = nil,
        workingDirectory: String? = nil
    ) throws -> PTYProcess {
        // Prepare all C strings before fork
        let cCommand = command.withCString { strdup($0)! }
        defer { free(cCommand) }

        // argv: [command, ...args, NULL]
        var argvPtrs: [UnsafeMutablePointer<CChar>?] = [cCommand]
        let cArgs = arguments.map { $0.withCString { strdup($0)! } }
        argvPtrs.append(contentsOf: cArgs.map { Optional($0) })
        argvPtrs.append(nil)
        defer { cArgs.forEach { free($0) } }

        // envp: merge current environment with overrides
        var envDict = ProcessInfo.processInfo.environment
        envDict["TERM"] = "xterm-256color"
        envDict["LANG"] = "en_US.UTF-8"
        if let extra = environment {
            envDict.merge(extra) { _, new in new }
        }
        let cEnv = envDict.map { "\($0.key)=\($0.value)".withCString { strdup($0)! } }
        var envpPtrs: [UnsafeMutablePointer<CChar>?] = cEnv.map { Optional($0) }
        envpPtrs.append(nil)
        defer { cEnv.forEach { free($0) } }

        let cwd: UnsafeMutablePointer<CChar>?
        if let dir = workingDirectory {
            cwd = dir.withCString { strdup($0)! }
        } else {
            cwd = nil
        }
        defer { cwd.map { free($0) } }

        // Set up terminal size
        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)

        var masterFD: Int32 = -1
        let pid = forkpty(&masterFD, nil, nil, &winSize)

        if pid < 0 {
            throw PTYError.forkFailed(errno)
        }

        if pid == 0 {
            // ---- Child process (only async-signal-safe calls) ----
            if let dir = cwd {
                _ = chdir(dir)
            }
            _ = argvPtrs.withUnsafeMutableBufferPointer { argvBuf in
                envpPtrs.withUnsafeMutableBufferPointer { envpBuf in
                    execve(cCommand, argvBuf.baseAddress, envpBuf.baseAddress)
                }
            }
            // execve only returns on failure
            _exit(127)
        }

        // ---- Parent process ----
        return PTYProcess(masterFD: masterFD, pid: pid)
    }
}

enum PTYError: Error, LocalizedError {
    case forkFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .forkFailed(let code): "forkpty() failed with errno \(code)"
        }
    }
}
