import AppKit
import CGhostty

/// Singleton wrapper around ghostty_app_t. One per application lifetime.
/// Manages global ghostty state, configuration, and runtime callbacks.
final class GhosttyApp {
    static let shared = GhosttyApp()

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?

    /// Called when ghostty dispatches a new_tab action (e.g. Cmd+T keybinding).
    var onNewTab: (() -> Void)?

    private var focusObservers: [NSObjectProtocol] = []

    private init() {
        Log.ghostty.info("Initializing ghostty backend...")

        // Initialize the ghostty backend
        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            Log.ghostty.error("ghostty_init failed")
            return
        }

        // Create configuration
        guard let cfg = ghostty_config_new() else {
            Log.ghostty.error("ghostty_config_new failed")
            return
        }

        // Load default config files (user's ~/.config/ghostty/config)
        ghostty_config_load_default_files(cfg)
        ghostty_config_load_recursive_files(cfg)
        ghostty_config_finalize(cfg)
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
        case GHOSTTY_ACTION_NEW_TAB:
            DispatchQueue.main.async {
                GhosttyApp.shared.onNewTab?()
            }
            return true
        case GHOSTTY_ACTION_NEW_WINDOW,
             GHOSTTY_ACTION_NEW_SPLIT:
            // Not supported yet — block to prevent crashes
            return true
        case GHOSTTY_ACTION_QUIT,
             GHOSTTY_ACTION_CLOSE_WINDOW,
             GHOSTTY_ACTION_CLOSE_ALL_WINDOWS,
             GHOSTTY_ACTION_CLOSE_TAB:
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
        guard let view = surfaceView(from: target) else { return false }
        guard let pwd = v.pwd else { return false }
        let pwdStr = String(cString: pwd)
        DispatchQueue.main.async {
            view.pwdDidChange?(pwdStr)
        }
        return true
    }

    private static func setMouseShape(target: ghostty_target_s, shape: ghostty_action_mouse_shape_e) -> Bool {
        guard surfaceView(from: target) != nil else { return false }
        DispatchQueue.main.async {
            switch shape {
            case GHOSTTY_MOUSE_SHAPE_TEXT:
                NSCursor.iBeam.set()
            case GHOSTTY_MOUSE_SHAPE_POINTER:
                NSCursor.pointingHand.set()
            default:
                NSCursor.arrow.set()
            }
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
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let str = pasteboard.string(forType: .string) ?? ""
            str.withCString { ptr in
                ghostty_surface_complete_clipboard_request(
                    state,
                    ptr,
                    nil,
                    true
                )
            }
        }
    }

    private static func confirmClipboardRead(_ state: UnsafeMutableRawPointer?) {
        // Auto-confirm
        ghostty_surface_complete_clipboard_request(state, nil, nil, true)
    }

    private static func writeClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        len: Int,
        confirm: Bool
    ) {
        guard let content, len > 0 else { return }
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            // Get the first content item
            let item = content.pointee
            if let data = item.data {
                pasteboard.setString(String(cString: data), forType: .string)
            }
        }
    }

    private static func closeSurface(_ userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
        // userdata here is GhosttyApp (the runtime userdata), not a surface view.
        // Surface close is already handled via GHOSTTY_ACTION_SHOW_CHILD_EXITED.
    }
}
