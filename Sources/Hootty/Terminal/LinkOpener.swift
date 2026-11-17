import AppKit
import CGhostty
import HoottyCore

/// Opens links the user Cmd-clicks in a terminal (`GHOSTTY_ACTION_OPEN_URL`).
///
/// Link targets come from terminal output, which any program (or a remote
/// host) controls. Following Ghostty's macOS app, targets go through
/// `UntrustedURL`: web and mail links open, custom schemes ask first, and
/// executable or malformed local targets are blocked (GHSA-cw69-wm67-5pv8,
/// GHSA-mfw9-xcr3-7gfp). Never hand them to `NSWorkspace.open` directly.
enum LinkOpener {
    static func open(_ action: ghostty_action_open_url_s) -> Bool {
        guard let ptr = action.url,
              let raw = String(bytes: UnsafeRawBufferPointer(start: ptr, count: Int(action.len)), encoding: .utf8)
        else { return true }

        switch action.kind {
        case GHOSTTY_ACTION_OPEN_URL_KIND_TEXT, GHOSTTY_ACTION_OPEN_URL_KIND_HTML:
            // libghostty's own files (config, generated HTML), not terminal output.
            NSWorkspace.shared.open(fileURL(for: raw))
            return true
        case GHOSTTY_ACTION_OPEN_URL_KIND_OSC8:
            openUntrusted(raw)
            return true
        default:
            // Regex-matched text: may be a plain path, which UntrustedURL
            // rejects, so check the file URL it names. Values with unsafe
            // characters pass unchanged so they're rejected before
            // percent-encoding hides them.
            let hasScheme = URL(string: raw)?.scheme != nil
            let target = hasScheme || UntrustedURL.containsUnsafeCharacters(raw)
                ? raw
                : fileURL(for: raw).absoluteString
            openUntrusted(target)
            // Always handled: false would make libghostty retry with its
            // unrestricted fallback opener.
            return true
        }
    }

    /// A URL with a scheme as-is; anything else is a path, with `~` expanded.
    private static func fileURL(for raw: String) -> URL {
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(filePath: NSString(string: raw).standardizingPath)
    }

    private static func openUntrusted(_ value: String) {
        let target = UntrustedURL(value)
        // The action callback runs with the renderer mutex held; present on
        // the next main-loop turn so AppKit can't re-enter a render callback.
        DispatchQueue.main.async {
            switch target.decision {
            case let .allow(url):
                NSWorkspace.shared.open(url)
            case let .confirm(url):
                confirmOpen(url, displayString: target.displayString)
            case let .deny(reason):
                showBlocked(reason, displayString: target.displayString)
            }
        }
    }

    private static func confirmOpen(_ url: URL, displayString: String) {
        let handler = NSWorkspace.shared.urlForApplication(toOpen: url)
            .map { "\u{201C}\($0.deletingPathExtension().lastPathComponent)\u{201D}" }
            ?? "the default application"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Open Link from Terminal Output?"
        alert.informativeText = "This link will open in \(handler). Only continue if you recognize and trust the destination."
        alert.accessoryView = targetView(displayString)
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Open Link")
        present(alert) { response in
            guard response == .alertSecondButtonReturn else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private static func showBlocked(_ reason: UntrustedURL.DenialReason, displayString: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Hootty Blocked This Link"
        alert.informativeText = reason.message
        alert.accessoryView = targetView(displayString)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy Link")
        present(alert) { response in
            // Copying, not opening, so there's no one-click bypass.
            guard response == .alertSecondButtonReturn else { return }
            NSPasteboard.general.copyString(displayString)
        }
    }

    private static func present(_ alert: NSAlert, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private static func targetView(_ target: String) -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 72))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let textView = NSTextView(frame: scroll.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]
        textView.string = target
        scroll.documentView = textView
        return scroll
    }
}
