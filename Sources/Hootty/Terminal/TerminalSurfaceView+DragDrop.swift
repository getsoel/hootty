import AppKit
import CGhostty

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
        let resolved: String? = if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            urls.map { shellEscape($0.path) }.joined(separator: " ")
        } else if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                  let url = urls.first {
            shellEscape(url.absoluteString)
        } else if let str = pb.string(forType: .string), !str.isEmpty {
            str
        } else {
            nil
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
