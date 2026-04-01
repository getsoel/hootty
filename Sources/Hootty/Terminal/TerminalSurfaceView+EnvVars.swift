import CGhostty
import Foundation

// MARK: - Hootty Env Vars

extension TerminalSurfaceView {
    /// Inject HOOTTY_PANE_ID and prepend our bin/ to PATH in the surface config.
    /// Returns allocated C strings that must be freed after `ghostty_surface_new`.
    func applyHoottyEnvVars(to config: inout ghostty_surface_config_s) -> (cStrings: [UnsafeMutablePointer<CChar>], envArray: UnsafeMutablePointer<ghostty_env_var_s>) {
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        var envVars: [ghostty_env_var_s] = []

        func addVar(_ key: String, _ value: String) {
            let k = strdup(key)!
            let v = strdup(value)!
            cStrings.append(k)
            cStrings.append(v)
            envVars.append(ghostty_env_var_s(key: k, value: v))
        }

        addVar("HOOTTY_PANE_ID", paneID.uuidString)

        // Reset stale Kitty keyboard protocol modes at each bash prompt.
        // `CSI < 9 u` pops up to 9 entries from the keyboard mode stack.
        // Safe on an empty stack (entries are already .disabled). Only bash processes PROMPT_COMMAND.
        let kittyReset = "printf '\\e[<9u'"
        let existingPromptCmd = ProcessInfo.processInfo.environment["PROMPT_COMMAND"] ?? ""
        if existingPromptCmd.isEmpty {
            addVar("PROMPT_COMMAND", kittyReset)
        } else {
            addVar("PROMPT_COMMAND", "\(kittyReset);\(existingPromptCmd)")
        }

        if let binPath = Self.hoottyBinPath {
            let current = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
            addVar("PATH", "\(binPath):\(current)")
        }

        let arr = UnsafeMutablePointer<ghostty_env_var_s>.allocate(capacity: envVars.count)
        for (i, ev) in envVars.enumerated() {
            arr[i] = ev
        }
        config.env_vars = arr
        config.env_var_count = envVars.count

        return (cStrings, arr)
    }

    /// Free allocations from `applyHoottyEnvVars`.
    func freeEnvVarAllocations(_ cStrings: [UnsafeMutablePointer<CChar>], _ envArray: UnsafeMutablePointer<ghostty_env_var_s>) {
        for ptr in cStrings {
            free(ptr)
        }
        envArray.deallocate()
    }
}
