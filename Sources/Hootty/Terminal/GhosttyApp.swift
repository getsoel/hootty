import AppKit
import CGhostty
import HoottyCore

/// Singleton wrapper around ghostty_app_t. One per application lifetime.
/// Manages global ghostty state, configuration, and runtime callbacks.
final class GhosttyApp {
    static let shared = GhosttyApp()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?

    /// The currently focused terminal surface (set by TerminalSurfaceView focus changes).
    var focusedSurface: ghostty_surface_t?

    /// Called when ghostty dispatches a new_tab action (e.g. Cmd+T keybinding).
    var onNewTab: (() -> Void)?

    /// Called when a surface rings the bell or sends a desktop notification.
    var onPaneNeedsAttention: ((UUID) -> Void)?

    /// Called when a Claude Code session ID is detected via OSC 9 (paneID, sessionID).
    var onClaudeSessionDetected: ((UUID, String) -> Void)?

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

    /// Path to Hootty-managed ghostty config file.
    private static let configFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Hootty", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ghostty.config")
    }()

    /// Write theme config to disk and return the file path.
    private static func writeThemeConfig(_ theme: TerminalTheme) -> String {
        let content = theme.generateGhosttyConfig()
        let path = configFileURL.path
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        Log.ghostty.info("Wrote ghostty config to \(path)")
        return path
    }

    /// Build a ghostty config, loading Hootty theme defaults then user overrides.
    private static func buildConfig(theme: TerminalTheme) -> ghostty_config_t? {
        guard let cfg = ghostty_config_new() else {
            Log.ghostty.error("ghostty_config_new failed")
            return nil
        }
        // Load Hootty-managed theme config first (provides defaults)
        let path = writeThemeConfig(theme)
        path.withCString { ghostty_config_load_file(cfg, $0) }
        // Load user's own ghostty config on top (overrides if present)
        ghostty_config_load_default_files(cfg)
        ghostty_config_load_recursive_files(cfg)
        ghostty_config_finalize(cfg)
        return cfg
    }

    private init() {
        Log.ghostty.info("Initializing ghostty backend...")

        // Initialize the ghostty backend
        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            Log.ghostty.error("ghostty_init failed")
            return
        }

        // Create configuration with current theme
        let theme = ThemeManager().theme
        guard let cfg = Self.buildConfig(theme: theme) else { return }
        self.config = cfg
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

    /// Reload ghostty config with a new theme. Updates all existing surfaces.
    func reloadConfig(theme: TerminalTheme) {
        guard let app else { return }
        guard let newConfig = Self.buildConfig(theme: theme) else { return }
        let oldConfig = self.config
        self.config = newConfig
        ghostty_app_update_config(app, newConfig)
        if let oldConfig { ghostty_config_free(oldConfig) }
        Log.ghostty.info("Reloaded ghostty config with new theme")
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
            return signalAttention(target: target)
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

    private static func signalAttention(target: ghostty_target_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID
        DispatchQueue.main.async {
            GhosttyApp.shared.onPaneNeedsAttention?(paneID)
        }
        return true
    }

    private static let hoottySessionPrefix = "hootty:session:"

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
        } else {
            DispatchQueue.main.async {
                GhosttyApp.shared.onPaneNeedsAttention?(paneID)
            }
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
