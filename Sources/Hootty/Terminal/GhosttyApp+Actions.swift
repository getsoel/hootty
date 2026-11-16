import AppKit
import CGhostty
import HoottyCore

// MARK: - Action Dispatch

extension GhosttyApp {
    static func handleAction(
        _: ghostty_app_t,
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
        case GHOSTTY_ACTION_PROGRESS_REPORT:
            return handleProgressReport(target: target, v: action.action.progress_report)
        case GHOSTTY_ACTION_PROGRAM_STATUS:
            return handleProgramStatus(target: target, v: action.action.program_status)
        case GHOSTTY_ACTION_NEW_TAB:
            DispatchQueue.main.async {
                GhosttyApp.shared.onEvent?(.newTab)
            }
            return true
        case GHOSTTY_ACTION_NEW_SPLIT:
            return handleNewSplit(target: target, v: action.action.new_split)
        case GHOSTTY_ACTION_NEW_WINDOW:
            return true
        case GHOSTTY_ACTION_CLOSE_TAB:
            DispatchQueue.main.async {
                GhosttyApp.shared.onEvent?(.closeTab)
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
        GhosttyApp.shared.onEvent?(.bellRang(ctx.paneID))
        return true
    }

    /// OSC 9;4 progress reports. Claude Code brackets each turn with
    /// indeterminate/remove, which keeps presence working when the terminal
    /// title is disabled or renamed. `PaneEventHandler` ignores this for panes
    /// that are not already agent panes — plenty of ordinary tools report
    /// progress too. Error and pause states carry no presence meaning here.
    private static func handleProgressReport(target: ghostty_target_s, v: ghostty_action_progress_report_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let isBusy: Bool
        switch v.state {
        case GHOSTTY_PROGRESS_STATE_SET, GHOSTTY_PROGRESS_STATE_INDETERMINATE:
            isBusy = true
        case GHOSTTY_PROGRESS_STATE_REMOVE:
            isBusy = false
        default:
            return true
        }
        let paneID = ctx.paneID
        DispatchQueue.main.async {
            GhosttyApp.shared.onEvent?(.progressReport(paneID: paneID, isBusy: isBusy))
        }
        return true
    }

    private static let hoottyPrefix = "hootty:"
    private static let hoottySessionPrefix = "hootty:session:"
    private static let hoottyResumePrefix = "hootty:resume:"
    private static let hoottyPresencePrefix = "hootty:presence:"
    private static let hoottyAgentPrefix = "hootty:agent:"

    private static func handleDesktopNotification(target: ghostty_target_s, v: ghostty_action_desktop_notification_s) -> Bool {
        guard let ctx = callbackContext(from: target) else { return false }
        let paneID = ctx.paneID

        // Copy C string synchronously before async dispatch (ghostty may free the buffer)
        let body: String? = v.body.map { String(cString: $0) }

        guard let body, body.hasPrefix(hoottyPrefix) else {
            // Non-hootty OSC 9 → generic bell attention.
            GhosttyApp.shared.onEvent?(.paneNeedsAttention(paneID, .bell))
            return true
        }

        if body.hasPrefix(hoottySessionPrefix) {
            let sessionID = String(body.dropFirst(hoottySessionPrefix.count))
            guard UUID(uuidString: sessionID) != nil else {
                Log.ghostty.warning("Invalid agent session ID received: \(sessionID)")
                return true
            }
            DispatchQueue.main.async {
                GhosttyApp.shared.onEvent?(.agentSessionDetected(paneID: paneID, sessionID: sessionID))
            }
        } else if body.hasPrefix(hoottyResumePrefix) {
            // Payload: <uuid>[|<configDir>]. Split once on "|" so config-dir
            // paths (which never contain "|") survive intact.
            let payload = String(body.dropFirst(hoottyResumePrefix.count))
            let parts = payload.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let sessionID = String(parts[0])
            let configDir = parts.count > 1 ? String(parts[1]) : nil
            guard UUID(uuidString: sessionID) != nil else {
                Log.ghostty.warning("Invalid resumable session ID received: \(sessionID)")
                return true
            }
            DispatchQueue.main.async {
                GhosttyApp.shared.onEvent?(.agentResumableDetected(paneID: paneID, sessionID: sessionID, configDir: configDir))
            }
        } else if body.hasPrefix(hoottyPresencePrefix) {
            let value = String(body.dropFirst(hoottyPresencePrefix.count))
            let event: GhosttyEvent? = switch value {
            case "thinking": .hoottyPresence(paneID: paneID, presence: .thinking)
            case "idle": .hoottyPresence(paneID: paneID, presence: .idle)
            case "attention": .hoottyPresence(paneID: paneID, presence: .needsAttention)
            case "error": .hoottyError(paneID: paneID)
            default:
                nil
            }
            if let event {
                DispatchQueue.main.async {
                    GhosttyApp.shared.onEvent?(event)
                }
            } else {
                Log.ghostty.warning("Unknown hootty presence value: \(value)")
            }
        } else if body.hasPrefix(hoottyAgentPrefix) {
            let name = String(body.dropFirst(hoottyAgentPrefix.count))
            guard !name.isEmpty else { return true }
            DispatchQueue.main.async {
                GhosttyApp.shared.onEvent?(.hoottyAgentName(paneID: paneID, name: name))
            }
        } else {
            Log.ghostty.info("Unknown hootty protocol message: \(body)")
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
            GhosttyApp.shared.onEvent?(.titleChanged(paneID: paneID, title: titleStr))
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
            GhosttyApp.shared.onEvent?(.pwdChanged(paneID: paneID, path: pwdStr))
        }
        return true
    }

    private static func setMouseShape(target: ghostty_target_s, shape: ghostty_action_mouse_shape_e) -> Bool {
        guard let view = surfaceView(from: target) else { return false }
        DispatchQueue.main.async {
            let cursor: NSCursor = switch shape {
            case GHOSTTY_MOUSE_SHAPE_TEXT:
                .iBeam
            case GHOSTTY_MOUSE_SHAPE_POINTER:
                .pointingHand
            default:
                .arrow
            }
            view.setCursorShape(cursor)
        }
        return true
    }

    private static func setMouseVisibility(target _: ghostty_target_s, v: ghostty_action_mouse_visibility_e) -> Bool {
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
            GhosttyApp.shared.onEvent?(.newSplit(paneID: paneID, direction: direction, parentSurface: surface))
        }
        return true
    }

    /// OSC 7501 program status. libghostty has already validated the report
    /// against the spec (sizes, ids, base64, control characters) and answered
    /// the `OSC 7501 ; ?` support query; this only parses the body.
    private static func handleProgramStatus(target: ghostty_target_s, v: ghostty_action_program_status_s) -> Bool {
        guard let ctx = callbackContext(from: target), let data = v.data else { return false }
        // Copy the C string before async dispatch (ghostty frees the buffer).
        let body = String(cString: data)
        guard let report = ProgramStatusReport.parse(body) else {
            Log.ghostty.warning("Unparseable program status report: \(body)")
            return true
        }
        let paneID = ctx.paneID
        DispatchQueue.main.async {
            GhosttyApp.shared.onEvent?(.programStatus(paneID: paneID, report: report))
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
            GhosttyApp.shared.onEvent?(.commandFinished(paneID: paneID, exitCode: exitCode))
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

    /// The only clipboard representation Hootty serves or stores.
    private static let textMime = "text/plain"

    /// Serve a clipboard read. libghostty asks for MIME types (`mimes`) and,
    /// when `list` is set, the types available. Hootty only handles text.
    static func readClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location _: ghostty_clipboard_e,
        state: UnsafeMutableRawPointer?,
        mimes: UnsafePointer<UnsafePointer<CChar>?>?,
        mimesLen: Int,
        list: Bool
    ) -> ghostty_clipboard_read_result_e {
        // userdata is the surface's SurfaceCallbackContext, not the runtime userdata.
        // Using focusedSurface here would silently drop pastes during transient focus changes.
        guard let userdata else { return GHOSTTY_CLIPBOARD_READ_UNSUPPORTED }
        let ctx = SurfaceCallbackContext.fromOpaque(userdata)
        guard let surface = ctx.view?.surface else { return GHOSTTY_CLIPBOARD_READ_UNSUPPORTED }

        let override = GhosttyApp.shared.pendingPasteOverride
        GhosttyApp.shared.pendingPasteOverride = nil
        let text = override ?? NSPasteboard.general.string(forType: .string)

        let wantsText = (0 ..< mimesLen).contains { index in
            guard let ptr = mimes?[index] else { return false }
            return String(cString: ptr).hasPrefix(textMime)
        }
        let contents: [(mime: String, data: Data)] = if wantsText, let text {
            [(textMime, Data(text.utf8))]
        } else {
            []
        }
        let available = list && text != nil ? [textMime] : []
        if contents.isEmpty, !list { return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE }

        completeClipboardRequest(surface, contents: contents, available: available, state: state)
        return GHOSTTY_CLIPBOARD_READ_STARTED
    }

    /// libghostty asks for confirmation (e.g. unsafe paste, OSC 52 read).
    /// Hootty has no confirmation UI and approves, completing with exactly the
    /// contents libghostty proposed so the clipboard isn't re-read.
    static func confirmClipboardRead(
        _ userdata: UnsafeMutableRawPointer?,
        confirm: UnsafePointer<ghostty_clipboard_confirm_s>?,
        state: UnsafeMutableRawPointer?
    ) {
        guard let userdata else { return }
        let ctx = SurfaceCallbackContext.fromOpaque(userdata)
        guard let surface = ctx.view?.surface else { return }
        guard let confirm else {
            ghostty_surface_deny_clipboard_request(surface, state)
            return
        }
        let request = confirm.pointee
        var contents: [(mime: String, data: Data)] = []
        if let items = request.contents {
            for index in 0 ..< request.contents_len {
                let item = items[index]
                guard let mime = item.mime else { continue }
                let data = item.len > 0 && item.data != nil ? Data(bytes: item.data, count: item.len) : Data()
                contents.append((String(cString: mime), data))
            }
        }
        var available: [String] = []
        if let names = request.available {
            for index in 0 ..< request.available_len {
                if let ptr = names[index] { available.append(String(cString: ptr)) }
            }
        }
        completeClipboardRequest(surface, contents: contents, available: available, state: state, confirmed: true)
    }

    /// Copy contents into C memory for the duration of the completion call.
    private static func completeClipboardRequest(
        _ surface: ghostty_surface_t,
        contents: [(mime: String, data: Data)],
        available: [String],
        state: UnsafeMutableRawPointer?,
        confirmed: Bool = false
    ) {
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        var cBuffers: [UnsafeMutableRawPointer] = []
        defer {
            cStrings.forEach { free($0) }
            cBuffers.forEach { $0.deallocate() }
        }

        var cContents: [ghostty_clipboard_content_s] = []
        for entry in contents {
            guard let mime = strdup(entry.mime) else { continue }
            cStrings.append(mime)
            let buffer = UnsafeMutableRawPointer.allocate(byteCount: max(entry.data.count, 1), alignment: 1)
            cBuffers.append(buffer)
            entry.data.withUnsafeBytes { source in
                if let base = source.baseAddress { buffer.copyMemory(from: base, byteCount: source.count) }
            }
            cContents.append(ghostty_clipboard_content_s(
                mime: mime, data: buffer.assumingMemoryBound(to: CChar.self), len: entry.data.count
            ))
        }
        var cAvailable: [UnsafePointer<CChar>?] = []
        for mime in available {
            guard let str = strdup(mime) else { continue }
            cStrings.append(str)
            cAvailable.append(UnsafePointer(str))
        }

        cContents.withUnsafeBufferPointer { contentsBuffer in
            cAvailable.withUnsafeBufferPointer { availableBuffer in
                var complete = ghostty_clipboard_complete_s(
                    contents: contentsBuffer.baseAddress,
                    contents_len: contentsBuffer.count,
                    available: availableBuffer.baseAddress,
                    available_len: availableBuffer.count,
                    confirmed: confirmed,
                    remember: false
                )
                ghostty_surface_complete_clipboard_request(surface, &complete, state)
            }
        }
    }

    /// Clipboard write (copy, OSC 52). Content is binary-safe with an explicit
    /// length and is NOT null-terminated, so never read it with `String(cString:)`.
    static func writeClipboard(
        _: UnsafeMutableRawPointer?,
        location _: ghostty_clipboard_e,
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        len: Int,
        confirm _: Bool
    ) {
        guard let content, len > 0 else { return }
        var text: String?
        for index in 0 ..< len {
            let item = content[index]
            guard let mime = item.mime, String(cString: mime).hasPrefix(textMime),
                  let data = item.data else { continue }
            text = String(bytes: UnsafeRawBufferPointer(start: data, count: item.len), encoding: .utf8)
            break
        }
        guard let text else { return }
        DispatchQueue.main.async {
            NSPasteboard.general.copyString(text)
        }
    }

    static func closeSurface(_: UnsafeMutableRawPointer?, processAlive _: Bool) {
        // userdata here is GhosttyApp (the runtime userdata), not a surface context.
        // Close is dispatched via onCloseSurface from the action callback or process exit handler.
    }
}
