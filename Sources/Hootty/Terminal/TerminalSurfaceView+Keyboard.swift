import AppKit
import CGhostty

// MARK: - Keyboard Events

extension TerminalSurfaceView {
    func handleKeyDown(with event: NSEvent) {
        onUserInteraction?()
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

    func handleKeyUp(with event: NSEvent) {
        sendKeyEvent(GHOSTTY_ACTION_RELEASE, event: event)
    }

    func handleFlagsChanged(with event: NSEvent) {
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

    func handlePerformKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        guard window?.firstResponder === self else { return false }
        guard let surface else { return false }

        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+0: let the SwiftUI menu handle "Focus Sidebar" instead of ghostty's reset_font_size
        if mods == .command && event.keyCode == 0x1D { // 0 key
            return false
        }

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

        // Claim Ctrl+Return to prevent AppKit's default context menu equivalent
        if mods.contains(.control) && event.keyCode == 0x24 { // Return
            self.keyDown(with: event)
            return true
        }

        // Claim Ctrl+/ and translate to Ctrl+_ (prevents macOS beep)
        if mods.contains(.control) && event.keyCode == 0x2C { // slash
            self.keyDown(with: event)
            return true
        }

        // Synthetic events (zero timestamp, e.g. Cmd+period → synthetic escape):
        // let AppKit handle them normally.
        if event.timestamp == 0 {
            return false
        }

        // All other non-command keys: return false so AppKit delivers both
        // keyDown: and keyUp: through normal dispatch. Claiming them here
        // suppresses keyUp (per Apple docs), which breaks arrow keys, etc.
        return false
    }

    // MARK: - Key Event Helpers

    func sendKeyEvent(
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

    func buildGhosttyKeyEvent(
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

    func ghosttyCharacters(from event: NSEvent) -> String? {
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

    func syncPreedit(clearIfNeeded: Bool) {
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

    func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
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

    func ghosttyEventModifierFlags(mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags(rawValue: 0)
        if mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue != 0 { flags.insert(.shift) }
        if mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0 { flags.insert(.control) }
        if mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0 { flags.insert(.option) }
        if mods.rawValue & GHOSTTY_MODS_SUPER.rawValue != 0 { flags.insert(.command) }
        return flags
    }
}
