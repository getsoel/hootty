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

    /// Called when a pane's thinking state changes (paneID, isThinking).
    var onPaneThinkingChanged: ((UUID, Bool) -> Void)?

    /// Called when ghostty dispatches a new_split action (e.g. keybinding).
    var onNewSplit: ((UUID, SplitDirection, ghostty_surface_t?) -> Void)?

    /// Called when a surface should be closed (process exit, close keybinding, etc.).
    var onCloseSurface: ((UUID) -> Void)?

    /// Called when ghostty dispatches a close_tab action.
    var onCloseTab: (() -> Void)?

    /// Called when a surface's working directory changes (paneID, newPath).
    var onPwdChanged: ((UUID, String) -> Void)?

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

    /// Copy all bundled theme files to app support so libghostty can resolve theme names.
    /// Sets `GHOSTTY_RESOURCES_DIR` env var before `ghostty_init()` is called.
    private static func ensureGhosttyResources() {
        let resourcesDir = ConfigFile.appSupportDirectory.appendingPathComponent("ghostty-resources")
        let themesDir = resourcesDir.appendingPathComponent("themes")
        try? FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)

        if let bundledURL = HoottyBundle.resourceBundle?.url(forResource: "Themes", withExtension: nil),
           let files = try? FileManager.default.contentsOfDirectory(at: bundledURL, includingPropertiesForKeys: nil) {
            for file in files where !file.lastPathComponent.hasPrefix(".") {
                let dest = themesDir.appendingPathComponent(file.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: file, to: dest)
            }
            Log.ghostty.info("Copied \(files.count) theme files to \(themesDir.path)")
        } else {
            // Fallback: write hardcoded Catppuccin Mocha so the app still works
            let file = themesDir.appendingPathComponent(ThemeCatalog.fallbackThemeName)
            try? ThemeCatalog.fallbackThemeContent.write(to: file, atomically: true, encoding: .utf8)
            Log.ghostty.warning("No bundled themes found, wrote fallback theme only")
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

    // MARK: - Callbacks

    private static func handleAction(
        _ app: ghostty_app_t,
        target: ghostty_target_s,
        action: ghostty_action_s
    ) -> Bool {
        Log.ghostty.debug("Action received: tag=\(action.tag.rawValue)")

        switch action.tag {
        case GHOSTTY_ACTION_SET_TITLE:
            return setTitle(target: target, v: action.action.set_title)
        case GHOSTTY_ACTION_PWD:
            return pwdChanged(target: target, v: action.action.pwd)
        case GHOSTTY_ACTION_MOUSE_SHAPE:
            return setMouseShape(target: target, shape: action.action.mouse_shape)
        case GHOSTTY_ACTION_MOUSE_VISIBILITY:
            return setMouseVisibility(target: target, v: action.action.mouse_visibility)
        case GHOSTTY_ACTION_RENDER:
            // ghostty handles rendering internally via Metal
            return true
        case GHOSTTY_ACTION_CELL_SIZE:
            return setCellSize(target: target, v: action.action.cell_size)
        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            return handleChildExited(target: target, v: action.action.child_exited)
        case GHOSTTY_ACTION_RING_BELL:
            return handleBell(target: target)
        case GHOSTTY_ACTION_DESKTOP_NOTIFICATION:
            return handleDesktopNotification(target: target, v: action.action.desktop_notification)
        case GHOSTTY_ACTION_NEW_TAB:
            DispatchQueue.main.async {
                GhosttyApp.shared.onNewTab?()
            }
            return true
        case GHOSTTY_ACTION_NEW_SPLIT:
            return handleNewSplit(target: target, v: action.action.new_split)
        case GHOSTTY_ACTION_NEW_WINDOW:
            return true
        case GHOSTTY_ACTION_CLOSE_TAB:
            DispatchQueue.main.async {
                GhosttyApp.shared.onCloseTab?()
            }
            return true
        case GHOSTTY_ACTION_CLOSE_WINDOW:
            DispatchQueue.main.async {
                NSApp.keyWindow?.close()
            }
            return true
        case GHOSTTY_ACTION_TOGGLE_COMMAND_PALETTE:
            DispatchQueue.main.async {
                GhosttyApp.shared.commandRegistry?.execute(.toggleCommandPalette)
            }
            return true
        case GHOSTTY_ACTION_GOTO_TAB:
            let tab = action.action.goto_tab
            DispatchQueue.main.async {
                if tab == GHOSTTY_GOTO_TAB_PREVIOUS {
                    GhosttyApp.shared.commandRegistry?.execute(.previousWorkspace)
                } else if tab == GHOSTTY_GOTO_TAB_NEXT || tab == GHOSTTY_GOTO_TAB_LAST {
                    GhosttyApp.shared.commandRegistry?.execute(.nextWorkspace)
                }
            }
            return true
        case GHOSTTY_ACTION_GOTO_SPLIT:
            let direction = action.action.goto_split
            DispatchQueue.main.async {
                switch direction {
                case GHOSTTY_GOTO_SPLIT_NEXT:
                    GhosttyApp.shared.commandRegistry?.execute(.focusNextPane)
                case GHOSTTY_GOTO_SPLIT_PREVIOUS:
                    GhosttyApp.shared.commandRegistry?.execute(.focusPreviousPane)
                case GHOSTTY_GOTO_SPLIT_UP:
                    GhosttyApp.shared.commandRegistry?.execute(.focusPaneUp)
                case GHOSTTY_GOTO_SPLIT_DOWN:
                    GhosttyApp.shared.commandRegistry?.execute(.focusPaneDown)
                case GHOSTTY_GOTO_SPLIT_LEFT:
                    GhosttyApp.shared.commandRegistry?.execute(.focusPaneLeft)
                case GHOSTTY_GOTO_SPLIT_RIGHT:
                    GhosttyApp.shared.commandRegistry?.execute(.focusPaneRight)
                default:
                    Log.ghostty.info("Unhandled goto_split direction: \(direction.rawValue)")
                }
            }
            return true
        case GHOSTTY_ACTION_EQUALIZE_SPLITS:
            DispatchQueue.main.async {
                GhosttyApp.shared.commandRegistry?.execute(.equalizeSplits)
            }
            return true
        case GHOSTTY_ACTION_QUIT,
             GHOSTTY_ACTION_CLOSE_ALL_WINDOWS:
            Log.ghostty.info("Blocked quit/close action: tag=\(action.tag.rawValue)")
            return true
        default:
            Log.ghostty.info("Unhandled action: tag=\(action.tag.rawValue)")
            return true
        }
    }

    private static func callbackContext(from target: ghostty_target_s) -> SurfaceCallbackContext? {
        guard target.tag == GHOSTTY_TARGET_SURFACE else { return nil }
        let surface = target.target.surface
        guard let ud = ghostty_surface_userdata(surface) else { return nil }
        return SurfaceCallbackContext.fromOpaque(ud)
    }

    private static func surfaceView(from target: ghostty_target_s) -> TerminalSurfaceView? {
        callbackContext(from: target)?.view
    }

    private static func handleBell(target: ghostty_target_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID
        GhosttyApp.shared.onBellRang?(paneID)
        return true
    }

    private static func signalAttention(target: ghostty_target_s, kind: AttentionKind = .input) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID
        GhosttyApp.shared.onPaneNeedsAttention?(paneID, kind)
        return true
    }

    private static let hoottySessionPrefix = "hootty:session:"
    private static let hoottyThinkingPrefix = "hootty:thinking:"
    private static let hoottyAttentionPrefix = "hootty:attention:"

    private static func handleDesktopNotification(target: ghostty_target_s, v: ghostty_action_desktop_notification_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID

        // Copy C string synchronously before async dispatch (ghostty may free the buffer)
        let body: String? = v.body.map { String(cString: $0) }

        if let body, body.hasPrefix(hoottySessionPrefix) {
            let sessionID = String(body.dropFirst(hoottySessionPrefix.count))
            guard UUID(uuidString: sessionID) != nil else {
                Log.ghostty.warning("Invalid Claude session ID received: \(sessionID)")
                return true
            }
            DispatchQueue.main.async {
                GhosttyApp.shared.onClaudeSessionDetected?(paneID, sessionID)
            }
        } else if let body, body.hasPrefix(hoottyThinkingPrefix) {
            let value = String(body.dropFirst(hoottyThinkingPrefix.count))
            guard value == "start" || value == "stop" else {
                Log.ghostty.warning("Invalid thinking state: \(value)")
                return true
            }
            let isThinking = value == "start"
            DispatchQueue.main.async {
                GhosttyApp.shared.onPaneThinkingChanged?(paneID, isThinking)
            }
        } else if let body, body.hasPrefix(hoottyAttentionPrefix) {
            let kindStr = String(body.dropFirst(hoottyAttentionPrefix.count))
            let kind = AttentionKind(rawValue: kindStr) ?? .input
            GhosttyApp.shared.onPaneNeedsAttention?(paneID, kind)
        } else {
            GhosttyApp.shared.onPaneNeedsAttention?(paneID, .input)
        }
        return true
    }

    private static func setTitle(target: ghostty_target_s, v: ghostty_action_set_title_s) -> Bool {
        guard let view = surfaceView(from: target) else { return false }
        guard let title = v.title else { return false }
        let titleStr = String(cString: title)
        DispatchQueue.main.async {
            view.titleDidChange?(titleStr)
        }
        return true
    }

    private static func pwdChanged(target: ghostty_target_s, v: ghostty_action_pwd_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        guard let pwd = v.pwd else { return false }
        let pwdStr = String(cString: pwd)
        let paneID = ctx.paneID
        DispatchQueue.main.async {
            ctx.view?.pwdDidChange?(pwdStr)
            GhosttyApp.shared.onPwdChanged?(paneID, pwdStr)
        }
        return true
    }

    private static func setMouseShape(target: ghostty_target_s, shape: ghostty_action_mouse_shape_e) -> Bool {
        guard let view = surfaceView(from: target) else { return false }
        DispatchQueue.main.async {
            let cursor: NSCursor
            switch shape {
            case GHOSTTY_MOUSE_SHAPE_TEXT:
                cursor = .iBeam
            case GHOSTTY_MOUSE_SHAPE_POINTER:
                cursor = .pointingHand
            default:
                cursor = .arrow
            }
            view.setCursorShape(cursor)
        }
        return true
    }

    private static func setMouseVisibility(target: ghostty_target_s, v: ghostty_action_mouse_visibility_e) -> Bool {
        DispatchQueue.main.async {
            NSCursor.setHiddenUntilMouseMoves(v == GHOSTTY_MOUSE_HIDDEN)
        }
        return true
    }

    private static func setCellSize(target: ghostty_target_s, v: ghostty_action_cell_size_s) -> Bool {
        guard let view = surfaceView(from: target) else { return false }
        DispatchQueue.main.async {
            view.cellSize = NSSize(width: Int(v.width), height: Int(v.height))
        }
        return true
    }

    private static func handleNewSplit(target: ghostty_target_s, v: ghostty_action_split_direction_e) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID
        let surface = target.target.surface
        let direction: SplitDirection = (v == GHOSTTY_SPLIT_DIRECTION_DOWN || v == GHOSTTY_SPLIT_DIRECTION_UP) ? .vertical : .horizontal
        DispatchQueue.main.async {
            GhosttyApp.shared.onNewSplit?(paneID, direction, surface)
        }
        return true
    }

    private static func handleChildExited(target: ghostty_target_s, v: ghostty_surface_message_childexited_s) -> Bool {
        guard let view = surfaceView(from: target) else { return false }
        DispatchQueue.main.async {
            view.processDidExit?(Int32(v.exit_code))
        }
        return true
    }

    // MARK: - Clipboard

    private static func readClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        state: UnsafeMutableRawPointer?
    ) {
        let surface = GhosttyApp.shared.focusedSurface
        DispatchQueue.main.async {
            guard let surface else { return }
            let str = NSPasteboard.general.string(forType: .string) ?? ""
            str.withCString { ptr in
                ghostty_surface_complete_clipboard_request(surface, ptr, state, true)
            }
        }
    }

    private static func confirmClipboardRead(_ state: UnsafeMutableRawPointer?) {
        guard let surface = GhosttyApp.shared.focusedSurface else { return }
        ghostty_surface_complete_clipboard_request(surface, nil, state, true)
    }

    private static func writeClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        len: Int,
        confirm: Bool
    ) {
        guard let content, len > 0 else { return }
        let item = content.pointee
        guard let data = item.data else { return }
        let str = String(cString: data)
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(str, forType: .string)
        }
    }

    private static func closeSurface(_ userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
        // userdata here is GhosttyApp (the runtime userdata), not a surface context.
        // Close is dispatched via onCloseSurface from the action callback or process exit handler.
    }

    /// Close a specific pane by ID. Called from action callbacks and process exit.
    static func requestCloseSurface(paneID: UUID) {
        DispatchQueue.main.async {
            GhosttyApp.shared.onCloseSurface?(paneID)
        }
    }
}
