import AppKit
import CGhostty

/// Asks the user before libghostty pastes text that looks dangerous, or lets a
/// program read the clipboard (OSC 52 / Kitty OSC 5522) or, when
/// `clipboard-write = ask`, write it.
///
/// libghostty decides when to ask (`clipboard-paste-protection`,
/// `clipboard-read`, `clipboard-write`); Hootty only shows the prompt.
enum ClipboardConfirmation {
    enum Kind {
        case paste
        case read
        case write

        init?(_ request: ghostty_clipboard_request_e) {
            switch request {
            case GHOSTTY_CLIPBOARD_REQUEST_PASTE: self = .paste
            case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ, GHOSTTY_CLIPBOARD_REQUEST_KITTY_READ: self = .read
            case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE, GHOSTTY_CLIPBOARD_REQUEST_KITTY_WRITE: self = .write
            default: return nil
            }
        }

        // The Kitty protocol's program-supplied name is deliberately not
        // shown: it is attacker-controlled text in a trusted prompt.
        var title: String {
            switch self {
            case .paste: "Paste possibly unsafe text?"
            case .read: "Allow a program to read the clipboard?"
            case .write: "Allow a program to write the clipboard?"
            }
        }

        var message: String {
            switch self {
            case .paste:
                "This text may run commands as soon as it is pasted."
            case .read:
                "A program in this terminal wants to read the clipboard. These are the contents it would get."
            case .write:
                "A program in this terminal wants to replace the clipboard with this content."
            }
        }

        var confirmTitle: String {
            switch self {
            case .paste: "Paste"
            case .read, .write: "Allow"
            }
        }
    }

    /// The most text shown in the preview; the rest is summarized.
    private static let previewLimit = 10000

    /// Shows the prompt as a sheet on `window` (or app-modal without one) and
    /// calls `completion(confirmed, remember)`. The safe choice is the default
    /// button, so an accidental Return denies.
    static func present(
        _ kind: Kind,
        preview: String,
        canRemember: Bool,
        window: NSWindow?,
        completion: @escaping (_ confirmed: Bool, _ remember: Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = kind.title
        alert.informativeText = kind.message
        alert.addButton(withTitle: kind == .paste ? "Cancel" : "Deny")
        alert.addButton(withTitle: kind.confirmTitle)
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        alert.accessoryView = previewView(preview)
        if canRemember {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Remember my choice until Hootty quits"
        }

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            let remember = canRemember && alert.suppressionButton?.state == .on
            completion(response == .alertSecondButtonReturn, remember)
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(alert.runModal())
        }
    }

    private static func previewView(_ text: String) -> NSView {
        var shown = text
        if shown.count > previewLimit {
            let omitted = shown.count - previewLimit
            shown = String(shown.prefix(previewLimit)) + "\n… \(omitted) more characters"
        }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let textView = NSTextView(frame: scroll.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]
        textView.string = shown
        scroll.documentView = textView
        return scroll
    }
}
