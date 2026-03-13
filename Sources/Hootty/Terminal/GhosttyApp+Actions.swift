import AppKit
import CGhostty
import HoottyCore

// MARK: - Action Dispatch

extension GhosttyApp {
    static func handleAction(
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
            return true
        case GHOSTTY_ACTION_CELL_SIZE:
            return setCellSize(target: target, v: action.action.cell_size)
        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            return handleChildExited(target: target, v: action.action.child_exited)
        case GHOSTTY_ACTION_COMMAND_FINISHED:
            return handleCommandFinished(target: target, v: action.action.command_finished)
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
            return handleGotoTab(action.action.goto_tab)
        case GHOSTTY_ACTION_GOTO_SPLIT:
            return handleGotoSplit(action.action.goto_split)
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

    // MARK: - Target Resolution

    static func callbackContext(from target: ghostty_target_s) -> SurfaceCallbackContext? {
        guard target.tag == GHOSTTY_TARGET_SURFACE else { return nil }
        let surface = target.target.surface
        guard let ud = ghostty_surface_userdata(surface) else { return nil }
        return SurfaceCallbackContext.fromOpaque(ud)
    }

    private static func surfaceView(from target: ghostty_target_s) -> TerminalSurfaceView? {
        callbackContext(from: target)?.view
    }

    // MARK: - Individual Action Handlers

    private static func handleBell(target: ghostty_target_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        GhosttyApp.shared.onBellRang?(ctx.paneID)
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
            GhosttyApp.shared.onPaneNeedsAttention?(paneID, .bell)
        }
        return true
    }

    private static func setTitle(target: ghostty_target_s, v: ghostty_action_set_title_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        guard let title = v.title else { return false }
        let titleStr = String(cString: title)
        let paneID = ctx.paneID
        DispatchQueue.main.async {
            ctx.view?.titleDidChange?(titleStr)
            GhosttyApp.shared.onTitleChanged?(paneID, titleStr)
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

    private static func handleCommandFinished(target: ghostty_target_s, v: ghostty_action_command_finished_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID
        let exitCode = v.exit_code
        DispatchQueue.main.async {
            GhosttyApp.shared.onCommandFinished?(paneID, exitCode)
        }
        return true
    }

    private static func handleGotoTab(_ tab: ghostty_action_goto_tab_e) -> Bool {
        DispatchQueue.main.async {
            if tab == GHOSTTY_GOTO_TAB_PREVIOUS {
                GhosttyApp.shared.commandRegistry?.execute(.previousWorkspace)
            } else if tab == GHOSTTY_GOTO_TAB_NEXT || tab == GHOSTTY_GOTO_TAB_LAST {
                GhosttyApp.shared.commandRegistry?.execute(.nextWorkspace)
            }
        }
        return true
    }

    private static func handleGotoSplit(_ direction: ghostty_action_goto_split_e) -> Bool {
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
    }

    // MARK: - Clipboard

    static func readClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        state: UnsafeMutableRawPointer?
    ) {
        let surface = GhosttyApp.shared.focusedSurface
        // Consume paste override synchronously (before async dispatch) to avoid races.
        let override = GhosttyApp.shared.pendingPasteOverride
        GhosttyApp.shared.pendingPasteOverride = nil
        DispatchQueue.main.async {
            guard let surface else { return }
            let str = override ?? NSPasteboard.general.string(forType: .string) ?? ""
            str.withCString { ptr in
                ghostty_surface_complete_clipboard_request(surface, ptr, state, true)
            }
        }
    }

    static func confirmClipboardRead(_ state: UnsafeMutableRawPointer?) {
        guard let surface = GhosttyApp.shared.focusedSurface else { return }
        ghostty_surface_complete_clipboard_request(surface, nil, state, true)
    }

    static func writeClipboard(
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

    static func closeSurface(_ userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
        // userdata here is GhosttyApp (the runtime userdata), not a surface context.
        // Close is dispatched via onCloseSurface from the action callback or process exit handler.
    }
}
