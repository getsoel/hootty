import AppKit
import CGhostty

// MARK: - Callback Context

/// Bridging object stored as ghostty surface userdata.
/// Uses `passRetained` so it stays alive as long as the surface exists.
/// Released explicitly during teardown.
final class SurfaceCallbackContext {
    weak var view: TerminalSurfaceView?
    let paneID: UUID

    init(view: TerminalSurfaceView, paneID: UUID) {
        self.view = view
        self.paneID = paneID
    }

    /// Store as retained opaque pointer (caller must balance with `release`).
    func retainedPointer() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(self).toOpaque()
    }

    /// Release the retained reference. Call exactly once per `retainedPointer()`.
    static func release(_ ptr: UnsafeMutableRawPointer) {
        Unmanaged<SurfaceCallbackContext>.fromOpaque(ptr).release()
    }

    /// Borrow without changing retain count.
    static func fromOpaque(_ ptr: UnsafeMutableRawPointer) -> SurfaceCallbackContext {
        Unmanaged<SurfaceCallbackContext>.fromOpaque(ptr).takeUnretainedValue()
    }
}

// MARK: - TerminalSurfaceView

/// NSView subclass that hosts a ghostty terminal surface.
/// Ghostty handles PTY, parsing, and Metal rendering internally.
/// This view forwards keyboard/mouse input and resize events to ghostty.
final class TerminalSurfaceView: NSView {

    // MARK: - Properties

    private(set) var surface: ghostty_surface_t?
    var cellSize: NSSize = .zero

    // Callbacks wired by the coordinator
    var titleDidChange: ((String) -> Void)?
    var pwdDidChange: ((String) -> Void)?
    var processDidExit: ((Int32) -> Void)?
    var onUserInteraction: (() -> Void)?
    var onFocusRequest: (() -> Void)?

    // IME state (internal for access from TerminalSurfaceView+Keyboard.swift)
    var markedText = NSMutableAttributedString()
    var keyTextAccumulator: [String]?

    // Deferred creation state
    private var ghosttyApp: ghostty_app_t?
    private var initialWorkingDirectory: String?
    private var parentSurface: ghostty_surface_t?
    private var surfaceCreated = false
    private var callbackContext: SurfaceCallbackContext?
    private var paneID: UUID

    // Pending text queue (for text sent before surface is ready)
    private var pendingTextQueue: [Data] = []
    private var pendingTextBytes = 0
    private static let maxPendingTextBytes = 1_048_576 // 1MB

    private var currentCursor: NSCursor = .iBeam

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Initialization

    init(app: ghostty_app_t, paneID: UUID, workingDirectory: String?, parentSurface: ghostty_surface_t? = nil) {
        self.ghosttyApp = app
        self.paneID = paneID
        self.initialWorkingDirectory = workingDirectory
        self.parentSurface = parentSurface
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        wantsLayer = true
        layer?.masksToBounds = true
        registerForDraggedTypes([.fileURL, .URL, .string])
        updateTrackingAreas()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        trackingAreas.forEach { removeTrackingArea($0) }
        NotificationCenter.default.removeObserver(self)

        // Capture refs synchronously before nilling — prevents stale access
        let surfaceToFree = surface
        let userdataPtr: UnsafeMutableRawPointer? = surfaceToFree.flatMap { ghostty_surface_userdata($0) }

        surface = nil
        callbackContext = nil

        // Async free to avoid re-entrant close/deinit loops.
        // Single Task ensures surface is freed before context is released.
        if surfaceToFree != nil || userdataPtr != nil {
            Task { @MainActor in
                if let surfaceToFree {
                    ghostty_surface_free(surfaceToFree)
                    Log.surface.info("Surface freed (async)")
                }
                if let userdataPtr {
                    SurfaceCallbackContext.release(userdataPtr)
                    Log.surface.info("Callback context released (async)")
                }
            }
        }

        Log.surface.info("Surface deinit completed")
    }

    // MARK: - Deferred Surface Creation

    private func createSurfaceIfNeeded() {
        guard !surfaceCreated, let app = ghosttyApp, window != nil else { return }
        surfaceCreated = true

        let ctx = SurfaceCallbackContext(view: self, paneID: paneID)
        self.callbackContext = ctx
        let userdataPtr = ctx.retainedPointer()

        if let parentSurface {
            // Inherited config path for split surfaces
            var config = ghostty_surface_inherited_config(parentSurface, GHOSTTY_SURFACE_CONTEXT_SPLIT)
            applyPlatformConfig(&config, userdata: userdataPtr)
            let envAlloc = applyHoottyEnvVars(to: &config)
            defer { freeEnvVarAllocations(envAlloc.cStrings, envAlloc.envArray) }
            self.surface = ghostty_surface_new(app, &config)
        } else {
            var config = ghostty_surface_config_new()
            applyPlatformConfig(&config, userdata: userdataPtr)
            let envAlloc = applyHoottyEnvVars(to: &config)
            defer { freeEnvVarAllocations(envAlloc.cStrings, envAlloc.envArray) }

            if let wd = initialWorkingDirectory {
                wd.withCString { ptr in
                    config.working_directory = ptr
                    self.surface = ghostty_surface_new(app, &config)
                }
            } else {
                self.surface = ghostty_surface_new(app, &config)
            }
        }

        // Clear references no longer needed
        ghosttyApp = nil
        initialWorkingDirectory = nil
        parentSurface = nil

        guard surface != nil else {
            Log.surface.error("Failed to create ghostty surface")
            SurfaceCallbackContext.release(userdataPtr)
            callbackContext = nil
            return
        }

        Log.surface.info("Surface created (deferred)")

        // Set display ID for vsync
        if let screen = window?.screen {
            ghostty_surface_set_display_id(surface!, screen.displayID ?? 0)
        }

        // Set initial content scale and size
        if let window {
            let scale = window.backingScaleFactor
            ghostty_surface_set_content_scale(surface!, scale, scale)
        }
        updateSurfaceSize(frame.size)

        // Force initial draw
        ghostty_surface_refresh(surface!)

        // Flush any pending text
        flushPendingText()
    }

    // MARK: - Hootty Env Vars

    private static let hoottyBinPath: String? = {
        HoottyBundle.resourceBundle?.url(forResource: "bin", withExtension: nil)?.path
    }()

    /// Inject HOOTTY_PANE_ID and prepend our bin/ to PATH in the surface config.
    /// Returns allocated C strings that must be freed after `ghostty_surface_new`.
    private func applyHoottyEnvVars(to config: inout ghostty_surface_config_s) -> (cStrings: [UnsafeMutablePointer<CChar>], envArray: UnsafeMutablePointer<ghostty_env_var_s>) {
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
        for (i, ev) in envVars.enumerated() { arr[i] = ev }
        config.env_vars = arr
        config.env_var_count = envVars.count

        return (cStrings, arr)
    }

    /// Free allocations from `applyHoottyEnvVars`.
    private func freeEnvVarAllocations(_ cStrings: [UnsafeMutablePointer<CChar>], _ envArray: UnsafeMutablePointer<ghostty_env_var_s>) {
        for ptr in cStrings { free(ptr) }
        envArray.deallocate()
    }

    private func applyPlatformConfig(_ config: inout ghostty_surface_config_s, userdata: UnsafeMutableRawPointer) {
        config.userdata = userdata
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(
                nsview: Unmanaged.passUnretained(self).toOpaque()
            )
        )
        config.scale_factor = Double(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0)
    }

    // MARK: - Pending Text Queue

    /// Queue text to be sent once the surface is created.
    func queueText(_ text: String) {
        guard surface == nil else {
            // Surface exists — send directly
            text.withCString { ptr in
                ghostty_surface_text(surface!, ptr, UInt(text.utf8.count))
            }
            return
        }

        guard let data = text.data(using: .utf8) else { return }
        guard pendingTextBytes + data.count <= Self.maxPendingTextBytes else {
            Log.surface.warning("Pending text queue full, dropping text")
            return
        }

        pendingTextQueue.append(data)
        pendingTextBytes += data.count
    }

    private func flushPendingText() {
        guard let surface, !pendingTextQueue.isEmpty else { return }
        Log.surface.info("Flushing \(self.pendingTextQueue.count) pending text items")

        for data in pendingTextQueue {
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                ghostty_surface_text(surface, ptr, UInt(data.count))
            }
        }

        pendingTextQueue.removeAll()
        pendingTextBytes = 0
    }

    // MARK: - NSView Overrides

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            Log.surface.info("Surface attached to window (pane: \(self.paneID.uuidString.prefix(8)), created: \(self.surfaceCreated))")
        } else {
            Log.surface.info("Surface detached from window (pane: \(self.paneID.uuidString.prefix(8)))")
        }

        // Deferred creation: create surface on first window attachment
        if !surfaceCreated {
            createSurfaceIfNeeded()
        }

        // Install occlusion observer for the new window
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowOcclusionDidChange(_:)),
                name: NSWindow.didChangeOcclusionStateNotification,
                object: window
            )
        }

        guard let surface, let window else { return }

        // Update content scale
        let scale = window.backingScaleFactor
        ghostty_surface_set_content_scale(surface, scale, scale)
        updateSurfaceSize(frame.size)

        // Update display ID for vsync
        if let screen = window.screen {
            ghostty_surface_set_display_id(surface, screen.displayID ?? 0)
        }

        // Force redraw when reattached to a window (e.g., SwiftUI .id() change
        // reparenting the NSView). Without this the Metal surface stays blank.
        ghostty_surface_refresh(surface)
    }

    @objc private func windowOcclusionDidChange(_ notification: Notification) {
        guard let surface else { return }
        let visible = window?.occlusionState.contains(.visible) ?? false
        ghostty_surface_set_occlusion(surface, visible)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let surface, let window else { return }

        // Update layer scale
        if let layer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.contentsScale = window.backingScaleFactor
            CATransaction.commit()
        }

        let fbFrame = convertToBacking(frame)
        let xScale = fbFrame.size.width / frame.size.width
        let yScale = fbFrame.size.height / frame.size.height
        ghostty_surface_set_content_scale(surface, xScale, yScale)

        updateSurfaceSize(frame.size)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateSurfaceSize(newSize)
    }

    private func updateSurfaceSize(_ size: NSSize) {
        guard let surface else { return }
        let scaledSize = convertToBacking(size)
        guard scaledSize.width > 0, scaledSize.height > 0 else { return }
        ghostty_surface_set_size(surface, UInt32(scaledSize.width), UInt32(scaledSize.height))
    }

    func refreshSurface() {
        guard let surface else { return }
        ghostty_surface_refresh(surface)
    }

    func setCursorShape(_ cursor: NSCursor) {
        currentCursor = cursor
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: currentCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        currentCursor.set()
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .inVisibleRect, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    // MARK: - Focus

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, true)
            GhosttyApp.shared.focusedSurface = surface

            // Re-assert display ID on focus
            if let screen = window?.screen {
                ghostty_surface_set_display_id(surface, screen.displayID ?? 0)
            }
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, false)
            if GhosttyApp.shared.focusedSurface == surface {
                GhosttyApp.shared.focusedSurface = nil
            }
        }
        return result
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        onUserInteraction?()
        onFocusRequest?()
        window?.makeFirstResponder(self)
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(surface, pos.x, frame.height - pos.y, ghosttyMods(event.modifierFlags))
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, ghosttyMods(event.modifierFlags))
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, ghosttyMods(event.modifierFlags))
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let surface else { return super.rightMouseDown(with: event) }
        if ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, ghosttyMods(event.modifierFlags)) {
            return
        }
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, ghosttyMods(event.modifierFlags))
    }

    override func mouseEntered(with event: NSEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.currentCursor.set()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        reportMousePosition(for: event)
        DispatchQueue.main.async { [weak self] in
            self?.currentCursor.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        reportMousePosition(for: event)
    }

    private func reportMousePosition(for event: NSEvent) {
        guard let surface else { return }
        let pos = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(surface, pos.x, frame.height - pos.y, ghosttyMods(event.modifierFlags))
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        var x = event.scrollingDeltaX
        var y = event.scrollingDeltaY
        if event.hasPreciseScrollingDeltas {
            x *= 2
            y *= 2
        }

        // Build scroll mods: bit 0 = precise, bits 1-2 = momentum phase
        var mods: Int32 = 0
        if event.hasPreciseScrollingDeltas { mods |= 1 }

        // Encode momentum phase
        switch event.momentumPhase {
        case .began:   mods |= (1 << 1)
        case .changed: mods |= (2 << 1)
        case .ended:   mods |= (3 << 1)
        default: break
        }

        ghostty_surface_mouse_scroll(surface, x, y, mods)
    }

    // MARK: - Keyboard Events (delegated to TerminalSurfaceView+Keyboard.swift)

    override func keyDown(with event: NSEvent) {
        handleKeyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        handleKeyUp(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        handleFlagsChanged(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handlePerformKeyEquivalent(with: event)
    }
}

// MARK: - NSTextInputClient

extension TerminalSurfaceView: NSTextInputClient {
    func insertText(_ string: Any, replacementRange: NSRange) {
        let str: String
        if let s = string as? NSAttributedString {
            str = s.string
        } else if let s = string as? String {
            str = s
        } else {
            return
        }

        // Clear marked text on insert
        markedText = NSMutableAttributedString()

        if keyTextAccumulator != nil {
            keyTextAccumulator?.append(str)
        } else {
            // Direct text input (not from keyDown)
            guard let surface else {
                queueText(str)
                return
            }
            str.withCString { ptr in
                ghostty_surface_text(surface, ptr, UInt(str.utf8.count))
            }
        }
    }

    override func doCommand(by selector: Selector) {
        // Intentionally empty: prevents NSBeep for unhandled selectors.
        // interpretKeyEvents() dispatches command selectors (moveUp:, insertNewline:, etc.)
        // for non-text keys. The default NSResponder implementation beeps for each one.
        // We handle all key input via ghostty_surface_key() instead.
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        if let s = string as? NSAttributedString {
            markedText = NSMutableAttributedString(attributedString: s)
        } else if let s = string as? String {
            markedText = NSMutableAttributedString(string: s)
        }
    }

    func unmarkText() {
        markedText = NSMutableAttributedString()
        guard let surface else { return }
        ghostty_surface_preedit(surface, nil, 0)
    }

    func selectedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    func markedRange() -> NSRange {
        if markedText.length > 0 {
            return NSRange(location: 0, length: markedText.length)
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    func hasMarkedText() -> Bool {
        markedText.length > 0
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let surface else { return .zero }
        var x: Double = 0, y: Double = 0, w: Double = 0, h: Double = 0
        ghostty_surface_ime_point(surface, &x, &y, &w, &h)
        let viewPoint = NSPoint(x: x, y: frame.height - y)
        guard let window else { return NSRect(origin: viewPoint, size: NSSize(width: w, height: h)) }
        let windowPoint = convert(viewPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        return NSRect(origin: screenPoint, size: NSSize(width: w, height: h))
    }

    func characterIndex(for point: NSPoint) -> Int {
        0
    }
}

// MARK: - Drag and Drop

extension TerminalSurfaceView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.canReadObject(forClasses: [NSURL.self], options: nil) ||
           pb.types?.contains(.string) == true {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        // Resolve drag content (same priority as before)
        let resolved: String?
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            resolved = urls.map { shellEscape($0.path) }.joined(separator: " ")
        } else if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                  let url = urls.first {
            resolved = shellEscape(url.absoluteString)
        } else if let str = pb.string(forType: .string), !str.isEmpty {
            resolved = str
        } else {
            resolved = nil
        }

        guard let content = resolved, let surface else { return false }

        onFocusRequest?()
        window?.makeFirstResponder(self)

        // Route through ghostty's paste path for bracketed paste wrapping.
        // Set override so readClipboard returns this content instead of the system pasteboard.
        GhosttyApp.shared.pendingPasteOverride = content
        let action = "paste_from_clipboard"
        let ok = ghostty_surface_binding_action(surface, action, UInt(action.utf8.count))
        if !ok {
            // Fallback: clear override and send directly
            GhosttyApp.shared.pendingPasteOverride = nil
            content.withCString { ptr in
                ghostty_surface_text(surface, ptr, UInt(content.utf8.count))
            }
        }
        return true
    }
}

// MARK: - NSScreen displayID

extension NSScreen {
    var displayID: UInt32? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return screenNumber.uint32Value
    }
}
