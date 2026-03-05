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

    // IME state
    private var markedText = NSMutableAttributedString()
    private var keyTextAccumulator: [String]?

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
        updateTrackingAreas()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        trackingAreas.forEach { removeTrackingArea($0) }
        NotificationCenter.default.removeObserver(self)

        // Capture refs before nilling — prevents stale access
        let surfaceToFree = surface
        let contextToRelease = callbackContext

        surface = nil
        callbackContext = nil

        // Async free to avoid re-entrant close/deinit loops
        if let surfaceToFree {
            Task { @MainActor in
                ghostty_surface_free(surfaceToFree)
                Log.surface.info("Surface freed (async)")
            }
        }

        if let contextToRelease, let ptr = ghostty_surface_userdata(surfaceToFree) {
            _ = contextToRelease // prevent unused warning — release happens via ptr
            Task { @MainActor in
                SurfaceCallbackContext.release(ptr)
                Log.surface.info("Callback context released (async)")
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

        if let parentSurface {
            // Inherited config path for split surfaces
            var config = ghostty_surface_inherited_config(parentSurface, GHOSTTY_SURFACE_CONTEXT_SPLIT)
            applyPlatformConfig(&config, userdata: ctx.retainedPointer())
            self.surface = ghostty_surface_new(app, &config)
        } else {
            var config = ghostty_surface_config_new()
            applyPlatformConfig(&config, userdata: ctx.retainedPointer())

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
        ghostty_surface_set_size(surface, UInt32(scaledSize.width), UInt32(scaledSize.height))
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .inVisibleRect, .activeAlways],
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

    override func mouseMoved(with event: NSEvent) {
        reportMousePosition(for: event)
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

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        guard let surface else {
            interpretKeyEvents([event])
            return
        }

        // Fast path: Ctrl+key bypasses IME entirely
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) && !flags.contains(.command) && !flags.contains(.option) {
            let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
            sendKeyEvent(action, event: event)
            return
        }

        let translationModsGhostty = ghosttyEventModifierFlags(
            mods: ghostty_surface_key_translation_mods(surface, ghosttyMods(event.modifierFlags))
        )

        var translationMods = event.modifierFlags
        for flag: NSEvent.ModifierFlags in [.shift, .control, .option, .command] {
            if translationModsGhostty.contains(flag) {
                translationMods.insert(flag)
            } else {
                translationMods.remove(flag)
            }
        }

        let translationEvent: NSEvent
        if translationMods == event.modifierFlags {
            translationEvent = event
        } else {
            translationEvent = NSEvent.keyEvent(
                with: event.type,
                location: event.locationInWindow,
                modifierFlags: translationMods,
                timestamp: event.timestamp,
                windowNumber: event.windowNumber,
                context: nil,
                characters: event.characters(byApplyingModifiers: translationMods) ?? "",
                charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
                isARepeat: event.isARepeat,
                keyCode: event.keyCode
            ) ?? event
        }

        let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
        let markedTextBefore = markedText.length > 0

        keyTextAccumulator = []
        defer { keyTextAccumulator = nil }

        interpretKeyEvents([translationEvent])
        syncPreedit(clearIfNeeded: markedTextBefore)

        if let list = keyTextAccumulator, !list.isEmpty {
            for text in list {
                sendKeyEvent(action, event: event, translationEvent: translationEvent, text: text)
            }
        } else {
            sendKeyEvent(action, event: event, translationEvent: translationEvent,
                        text: ghosttyCharacters(from: translationEvent), composing: markedText.length > 0 || markedTextBefore)
        }
    }

    override func keyUp(with event: NSEvent) {
        sendKeyEvent(GHOSTTY_ACTION_RELEASE, event: event)
    }

    override func flagsChanged(with event: NSEvent) {
        let mod: UInt32
        switch event.keyCode {
        case 0x39: mod = GHOSTTY_MODS_CAPS.rawValue
        case 0x38, 0x3C: mod = GHOSTTY_MODS_SHIFT.rawValue
        case 0x3B, 0x3E: mod = GHOSTTY_MODS_CTRL.rawValue
        case 0x3A, 0x3D: mod = GHOSTTY_MODS_ALT.rawValue
        case 0x37, 0x36: mod = GHOSTTY_MODS_SUPER.rawValue
        default: return
        }

        if hasMarkedText() { return }
        let mods = ghosttyMods(event.modifierFlags)
        var action = GHOSTTY_ACTION_RELEASE
        if mods.rawValue & mod != 0 {
            action = GHOSTTY_ACTION_PRESS
        }
        sendKeyEvent(action, event: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        guard window?.firstResponder === self else { return false }
        guard let surface else { return false }

        let keyEvent = buildGhosttyKeyEvent(GHOSTTY_ACTION_PRESS, event: event)
        var flags = ghostty_binding_flags_e(0)
        if ghostty_surface_key_is_binding(surface, keyEvent, &flags) {
            // If the binding is consumed, we handle it
            if flags.rawValue & GHOSTTY_BINDING_FLAGS_CONSUMED.rawValue != 0 {
                self.keyDown(with: event)
                return true
            }
        }

        // Claim Escape so AppKit doesn't propagate it as a cancel/close action
        if event.keyCode == 0x35 { // Escape
            self.keyDown(with: event)
            return true
        }

        return false
    }

    // MARK: - Key Event Helpers

    private func sendKeyEvent(
        _ action: ghostty_input_action_e,
        event: NSEvent,
        translationEvent: NSEvent? = nil,
        text: String? = nil,
        composing: Bool = false
    ) {
        guard let surface else { return }
        var keyEv = buildGhosttyKeyEvent(action, event: event, translationMods: translationEvent?.modifierFlags)
        keyEv.composing = composing

        if let text, !text.isEmpty, let codepoint = text.utf8.first, codepoint >= 0x20 {
            text.withCString { ptr in
                keyEv.text = ptr
                ghostty_surface_key(surface, keyEv)
            }
        } else {
            ghostty_surface_key(surface, keyEv)
        }
    }

    private func buildGhosttyKeyEvent(
        _ action: ghostty_input_action_e,
        event: NSEvent,
        translationMods: NSEvent.ModifierFlags? = nil
    ) -> ghostty_input_key_s {
        var keyEv = ghostty_input_key_s()
        keyEv.action = action
        keyEv.keycode = UInt32(event.keyCode)
        keyEv.text = nil
        keyEv.composing = false

        keyEv.mods = ghosttyMods(event.modifierFlags)
        keyEv.consumed_mods = ghosttyMods(
            (translationMods ?? event.modifierFlags).subtracting([.control, .command])
        )

        keyEv.unshifted_codepoint = 0
        if event.type == .keyDown || event.type == .keyUp {
            if let chars = event.characters(byApplyingModifiers: []),
               let codepoint = chars.unicodeScalars.first {
                keyEv.unshifted_codepoint = codepoint.value
            }
        }

        return keyEv
    }

    private func ghosttyCharacters(from event: NSEvent) -> String? {
        guard let characters = event.characters else { return nil }
        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            if scalar.value < 0x20 {
                return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }
        return characters
    }

    private func syncPreedit(clearIfNeeded: Bool) {
        guard let surface else { return }
        if markedText.length > 0 {
            let str = markedText.string
            str.withCString { ptr in
                ghostty_surface_preedit(surface, ptr, UInt(str.utf8.count))
            }
        } else if clearIfNeeded {
            ghostty_surface_preedit(surface, nil, 0)
        }
    }

    // MARK: - Modifier Conversion

    private func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods: UInt32 = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }

        let rawFlags = flags.rawValue
        if rawFlags & UInt(NX_DEVICERSHIFTKEYMASK) != 0 { mods |= GHOSTTY_MODS_SHIFT_RIGHT.rawValue }
        if rawFlags & UInt(NX_DEVICERCTLKEYMASK) != 0 { mods |= GHOSTTY_MODS_CTRL_RIGHT.rawValue }
        if rawFlags & UInt(NX_DEVICERALTKEYMASK) != 0 { mods |= GHOSTTY_MODS_ALT_RIGHT.rawValue }
        if rawFlags & UInt(NX_DEVICERCMDKEYMASK) != 0 { mods |= GHOSTTY_MODS_SUPER_RIGHT.rawValue }

        return ghostty_input_mods_e(mods)
    }

    private func ghosttyEventModifierFlags(mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags(rawValue: 0)
        if mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue != 0 { flags.insert(.shift) }
        if mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0 { flags.insert(.control) }
        if mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0 { flags.insert(.option) }
        if mods.rawValue & GHOSTTY_MODS_SUPER.rawValue != 0 { flags.insert(.command) }
        return flags
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

// MARK: - NSScreen displayID

extension NSScreen {
    var displayID: UInt32? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return screenNumber.uint32Value
    }
}
