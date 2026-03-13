import AppKit
import CGhostty
import HoottyCore

/// Singleton wrapper around ghostty_app_t. One per application lifetime.
/// Manages global ghostty state, configuration, and runtime callbacks.
final class GhosttyApp {
    static let shared = GhosttyApp()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?

    /// Theme resolved during initialization, before ThemeManager is wired up.
    /// Consumed once by HoottyApp.onAppear to push to ThemeManager.
    private(set) var initialTheme: TerminalTheme?

    /// The currently focused terminal surface (set by TerminalSurfaceView focus changes).
    var focusedSurface: ghostty_surface_t?

    /// Command registry for routing ghostty actions to app commands.
    weak var commandRegistry: CommandRegistry?

    /// Called when ghostty dispatches a new_tab action (e.g. Cmd+T keybinding).
    var onNewTab: (() -> Void)?

    /// Called when a surface rings the terminal bell (BEL character).
    var onBellRang: ((UUID) -> Void)?

    /// Called when a surface sends a desktop notification (attention events).
    var onPaneNeedsAttention: ((UUID, AttentionKind) -> Void)?

    /// Called when a Claude Code session ID is detected via OSC 9 (paneID, sessionID).
    var onClaudeSessionDetected: ((UUID, String) -> Void)?

    /// Called when ghostty dispatches a new_split action (e.g. keybinding).
    var onNewSplit: ((UUID, SplitDirection, ghostty_surface_t?) -> Void)?

    /// Called when a surface should be closed (process exit, close keybinding, etc.).
    var onCloseSurface: ((UUID) -> Void)?

    /// Called when ghostty dispatches a close_tab action.
    var onCloseTab: (() -> Void)?

    /// Called when a command finishes in a surface (shell integration required). (paneID, exitCode)
    var onCommandFinished: ((UUID, Int16) -> Void)?

    /// Called when a surface's working directory changes (paneID, newPath).
    var onPwdChanged: ((UUID, String) -> Void)?

    /// Called when a surface's title changes (paneID, title).
    var onTitleChanged: ((UUID, String) -> Void)?

    /// Pending paste content set by drag-and-drop to route through ghostty's paste path
    /// (which applies bracketed paste wrapping). Consumed by `readClipboard`.
    var pendingPasteOverride: String?

    /// Pending parent surfaces for inherited config during split creation.
    private var pendingParentSurfaces: [UUID: ghostty_surface_t] = [:]

    func registerParentSurface(_ paneID: UUID, surface: ghostty_surface_t) {
        pendingParentSurfaces[paneID] = surface
    }

    func consumeParentSurface(for paneID: UUID) -> ghostty_surface_t? {
        pendingParentSurfaces.removeValue(forKey: paneID)
    }

    /// Cached surface views keyed by pane ID.
    /// Prevents SwiftUI structural identity changes from destroying surfaces
    /// when the split tree restructures (e.g., leaf → split transition).
    private var surfaceViews: [UUID: TerminalSurfaceView] = [:]

    func cacheSurfaceView(_ view: TerminalSurfaceView, for paneID: UUID) {
        surfaceViews[paneID] = view
    }

    func cachedSurfaceView(for paneID: UUID) -> TerminalSurfaceView? {
        surfaceViews[paneID]
    }

    func refreshAllSurfaces() {
        for (_, view) in surfaceViews {
            view.refreshSurface()
        }
    }

    func removeCachedSurfaceView(for paneID: UUID) {
        surfaceViews.removeValue(forKey: paneID)
        pendingParentSurfaces.removeValue(forKey: paneID)
        pendingCommands.removeValue(forKey: paneID)
    }

    /// Remove all cached surface views and pending state for every pane in a workspace.
    func cleanupWorkspace(_ workspace: Workspace) {
        for pane in workspace.allPanes {
            removeCachedSurfaceView(for: pane.id)
        }
    }

    /// Pending commands to send to surfaces after creation (for session resume).
    private var pendingCommands: [UUID: String] = [:]

    func registerPendingCommand(_ paneID: UUID, command: String) {
        pendingCommands[paneID] = command
    }

    func consumePendingCommand(for paneID: UUID) -> String? {
        pendingCommands.removeValue(forKey: paneID)
    }

    private var focusObservers: [NSObjectProtocol] = []

    /// Path to derived ghostty config cache file (not user-facing).
    private static let ghosttyConfigCacheURL: URL = {
        let dir = ConfigFile.appSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".ghostty-cache.config")
    }()

    /// Write ghostty-only config content to cache file and return the file path.
    private static func writeGhosttyConfigFile(content: String) -> String {
        let path = ghosttyConfigCacheURL.path
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        Log.ghostty.info("Wrote ghostty config cache to \(path)")
        return path
    }

    /// Build a ghostty config from pre-filtered content string.
    /// Returns (config, resolvedTheme). Falls back to hardcoded palette on read failure.
    private static func buildConfig(ghosttyContent: String) -> (ghostty_config_t, TerminalTheme)? {
        guard let cfg = ghostty_config_new() else {
            Log.ghostty.error("ghostty_config_new failed")
            return nil
        }
        let path = writeGhosttyConfigFile(content: ghosttyContent)
        path.withCString { ghostty_config_load_file(cfg, $0) }
        ghostty_config_finalize(cfg)

        // Log any config diagnostics (warnings/errors from ghostty)
        let diagCount = ghostty_config_diagnostics_count(cfg)
        for i in 0..<diagCount {
            let diag = ghostty_config_get_diagnostic(cfg, i)
            if let msgPtr = diag.message {
                let msg = String(cString: msgPtr)
                Log.ghostty.warning("Config diagnostic [\(i)]: \(msg)")
            }
        }

        // Read resolved colors back from ghostty
        let theme: TerminalTheme
        if let resolved = GhosttyConfigReader.readTheme(from: cfg) {
            Log.ghostty.info("Read resolved theme colors from ghostty config")
            theme = resolved
        } else {
            Log.ghostty.warning("Falling back to parsing theme file directly")
            let parsed = ConfigFile.parse(ghosttyContent)
            let themeName = parsed["theme"] ?? ThemeCatalog.fallbackThemeName
            let themesDir = Self.themesDirectoryURL
            if let content = try? String(contentsOf: themesDir.appendingPathComponent(themeName), encoding: .utf8),
               let parsed = TerminalTheme.parse(ghosttyThemeContent: content) {
                theme = parsed
            } else {
                theme = TerminalTheme.parse(ghosttyThemeContent: ThemeCatalog.fallbackThemeContent)!
            }
        }
        return (cfg, theme)
    }

    /// URL to the themes directory within app support (ghostty-resources/themes).
    /// Used by HoottyApp to pass to AppModel for ThemeCatalog discovery.
    static var themesDirectoryURL: URL {
        ConfigFile.appSupportDirectory
            .appendingPathComponent("ghostty-resources")
            .appendingPathComponent("themes")
    }

    /// Copy all bundled theme files, terminfo, and shell-integration to app support
    /// so libghostty can resolve theme names and terminal capabilities.
    /// Sets `GHOSTTY_RESOURCES_DIR` env var before `ghostty_init()` is called.
    private static func ensureGhosttyResources() {
        let fm = FileManager.default
        let appSupportDir = ConfigFile.appSupportDirectory
        let resourcesDir = appSupportDir.appendingPathComponent("ghostty-resources")
        let themesDir = resourcesDir.appendingPathComponent("themes")
        try? fm.createDirectory(at: themesDir, withIntermediateDirectories: true)

        // Themes
        if let bundledURL = HoottyBundle.resourceBundle?.url(forResource: "Themes", withExtension: nil),
           let files = try? fm.contentsOfDirectory(at: bundledURL, includingPropertiesForKeys: nil) {
            for file in files where !file.lastPathComponent.hasPrefix(".") {
                let dest = themesDir.appendingPathComponent(file.lastPathComponent)
                try? fm.removeItem(at: dest)
                try? fm.copyItem(at: file, to: dest)
            }
            Log.ghostty.info("Copied \(files.count) theme files to \(themesDir.path)")
        } else {
            // Fallback: write hardcoded Catppuccin Mocha so the app still works
            let file = themesDir.appendingPathComponent(ThemeCatalog.fallbackThemeName)
            try? ThemeCatalog.fallbackThemeContent.write(to: file, atomically: true, encoding: .utf8)
            Log.ghostty.warning("No bundled themes found, wrote fallback theme only")
        }

        // Shell integration: deploy into ghostty-resources/shell-integration/
        let shellIntegrationDest = resourcesDir.appendingPathComponent("shell-integration")
        if let bundledURL = HoottyBundle.resourceBundle?.url(forResource: "shell-integration", withExtension: nil) {
            try? fm.removeItem(at: shellIntegrationDest)
            try? fm.copyItem(at: bundledURL, to: shellIntegrationDest)
            Log.ghostty.info("Deployed shell-integration to \(shellIntegrationDest.path)")
        } else {
            Log.ghostty.warning("No bundled shell-integration found — shell integration will not work")
        }

        // Terminfo: deploy into parent dir (dirname(resources_dir)/terminfo)
        // libghostty computes TERMINFO = dirname(GHOSTTY_RESOURCES_DIR) + "/terminfo"
        let terminfoDir = appSupportDir.appendingPathComponent("terminfo")
        if let bundledURL = HoottyBundle.resourceBundle?.url(forResource: "terminfo", withExtension: nil) {
            try? fm.removeItem(at: terminfoDir)
            try? fm.copyItem(at: bundledURL, to: terminfoDir)
            Log.ghostty.info("Deployed terminfo to \(terminfoDir.path)")
        } else {
            Log.ghostty.warning("No bundled terminfo found — terminal capabilities may be limited")
        }

        let path = resourcesDir.path
        setenv("GHOSTTY_RESOURCES_DIR", path, 1)
        Log.ghostty.info("Set GHOSTTY_RESOURCES_DIR=\(path)")
    }

    private init() {
        Log.ghostty.info("Initializing ghostty backend...")

        // Bootstrap theme files so ghostty can resolve `theme = catppuccin-*`
        Self.ensureGhosttyResources()

        // Initialize the ghostty backend
        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            Log.ghostty.error("ghostty_init failed")
            return
        }

        // Read config file to extract ghostty-only content
        let ghosttyContent = ConfigFile().ghosttyConfigContent()

        // Create configuration — ghostty resolves the built-in theme, we read colors back
        guard let (cfg, resolvedTheme) = Self.buildConfig(ghosttyContent: ghosttyContent) else { return }
        self.config = cfg
        self.initialTheme = resolvedTheme
        Log.ghostty.info("Config loaded")

        // Create runtime config with callbacks
        var runtimeCfg = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: { userdata in
                // Wakeup-driven tick: ghostty calls this when it needs processing
                DispatchQueue.main.async {
                    GhosttyApp.shared.tick()
                }
            },
            action_cb: { app, target, action in
                GhosttyApp.handleAction(app!, target: target, action: action)
            },
            read_clipboard_cb: { userdata, location, state in
                GhosttyApp.readClipboard(userdata, location: location, state: state)
            },
            confirm_read_clipboard_cb: { _, _, state, _ in
                // Auto-confirm clipboard reads
                GhosttyApp.confirmClipboardRead(state)
            },
            write_clipboard_cb: { userdata, location, content, len, confirm in
                GhosttyApp.writeClipboard(userdata, location: location, content: content, len: len, confirm: confirm)
            },
            close_surface_cb: { userdata, processAlive in
                GhosttyApp.closeSurface(userdata, processAlive: processAlive)
            }
        )

        // Create the app
        guard let app = ghostty_app_new(&runtimeCfg, cfg) else {
            Log.ghostty.error("ghostty_app_new failed")
            ghostty_config_free(cfg)
            self.config = nil
            return
        }

        self.app = app
        ghostty_app_set_focus(app, NSApp.isActive)
        Log.ghostty.info("Ghostty app created successfully")

        // Track app focus via notifications
        installFocusObservers()
    }

    deinit {
        for observer in focusObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        if let app { ghostty_app_free(app) }
        if let config { ghostty_config_free(config) }
    }

    func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    func setFocus(_ focused: Bool) {
        guard let app else { return }
        ghostty_app_set_focus(app, focused)
    }

    /// Reload ghostty config with new content. Updates all existing surfaces.
    /// Returns the resolved theme, or nil on failure.
    @discardableResult
    func reloadConfig(ghosttyContent: String) -> TerminalTheme? {
        guard let app else { return nil }
        guard let (newConfig, resolvedTheme) = Self.buildConfig(ghosttyContent: ghosttyContent) else { return nil }
        let oldConfig = self.config
        self.config = newConfig
        ghostty_app_update_config(app, newConfig)
        if let oldConfig { ghostty_config_free(oldConfig) }
        Log.ghostty.info("Reloaded ghostty config")
        return resolvedTheme
    }

    // MARK: - Focus Observers

    private func installFocusObservers() {
        let activateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setFocus(true)
        }

        let deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setFocus(false)
        }

        focusObservers = [activateObserver, deactivateObserver]
    }

    // Action dispatch, clipboard handlers, and close surface are in GhosttyApp+Actions.swift

    /// Close a specific pane by ID. Called from action callbacks and process exit.
    static func requestCloseSurface(paneID: UUID) {
        DispatchQueue.main.async {
            GhosttyApp.shared.onCloseSurface?(paneID)
        }
    }
}
