import AppKit
import CGhostty
import HoottyCore

/// Events dispatched from ghostty callbacks to the app layer.
/// Consolidates the many individual callback closures into a single dispatch point.
enum GhosttyEvent {
    case newTab
    case bellRang(UUID)
    case paneNeedsAttention(UUID, AttentionKind)
    case agentSessionDetected(paneID: UUID, sessionID: String)
    /// A resumable agent session captured via the hootty:resume: OSC 9 protocol.
    /// Carries the agent's real session UUID and optional CLAUDE_CONFIG_DIR.
    case agentResumableDetected(paneID: UUID, sessionID: String, configDir: String?)
    /// Explicit presence state from the hootty: OSC 9 protocol.
    case hoottyPresence(paneID: UUID, presence: AgentPresence)
    /// Explicit error state from the hootty: OSC 9 protocol.
    case hoottyError(paneID: UUID)
    /// Agent name set via the hootty:agent: OSC 9 protocol.
    case hoottyAgentName(paneID: UUID, name: String)
    case newSplit(paneID: UUID, direction: SplitDirection, parentSurface: ghostty_surface_t?)
    case closeSurface(UUID)
    case closeTab
    case commandFinished(paneID: UUID, exitCode: Int16)
    case pwdChanged(paneID: UUID, path: String)
    case titleChanged(paneID: UUID, title: String)
}

/// Singleton wrapper around ghostty_app_t. One per application lifetime.
/// Manages global ghostty state, configuration, and runtime callbacks.
@MainActor
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

    /// Single event handler for all ghostty events. Set once by HoottyApp.
    var onEvent: ((GhosttyEvent) -> Void)?

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

    func refreshAllSurfaces(paneIDs: Set<UUID>? = nil) {
        for (paneID, view) in surfaceViews {
            if let paneIDs, !paneIDs.contains(paneID) { continue }
            view.refreshSurface()
        }
    }

    func setOcclusion(visible: Bool, for workspace: Workspace) {
        for pane in workspace.allPanes {
            guard let surface = surfaceViews[pane.id]?.surface else { continue }
            ghostty_surface_set_occlusion(surface, visible)
        }
    }

    func removeCachedSurfaceView(for paneID: UUID) {
        if let view = surfaceViews.removeValue(forKey: paneID) {
            // Clear focusedSurface if it points to this surface (prevents dangling pointer
            // when the view is removed without resigning first responder)
            if let surface = view.surface, focusedSurface == surface {
                focusedSurface = nil
            }
        }
        pendingParentSurfaces.removeValue(forKey: paneID)
        pendingCommands.removeValue(forKey: paneID)
    }

    /// Remove all cached surface views and pending state for every pane in a workspace.
    func cleanupWorkspace(_ workspace: Workspace) {
        for pane in workspace.allPanes {
            removeCachedSurfaceView(for: pane.id)
        }
    }

    /// Log a warning if any surfaces remain after a profile-switch teardown (task 6.9).
    func assertTeardownComplete() {
        let remainingCount = surfaceViews.count
        if remainingCount > 0 {
            Log.ghostty.warning("Profile switch: \(remainingCount) surface view(s) remain after teardown — potential dangling ghostty_surface_t")
        }
        if focusedSurface != nil {
            Log.ghostty.warning("Profile switch: focusedSurface is not nil after teardown")
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

    /// Type `text` into a pane's terminal now, or queue it to run when the
    /// pane's surface is next created (e.g. a restored pane not yet shown).
    /// `queueText` itself buffers if the surface exists but isn't created yet.
    func injectText(_ text: String, into paneID: UUID) {
        if let view = cachedSurfaceView(for: paneID) {
            view.queueText(text)
        } else {
            registerPendingCommand(paneID, command: text)
        }
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
        for i in 0 ..< diagCount {
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
            wakeup_cb: { _ in
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
            confirm_read_clipboard_cb: { userdata, _, state, _ in
                GhosttyApp.confirmClipboardRead(userdata, state)
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
        let oldConfig = config
        config = newConfig
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
            GhosttyApp.shared.onEvent?(.closeSurface(paneID))
        }
    }
}
