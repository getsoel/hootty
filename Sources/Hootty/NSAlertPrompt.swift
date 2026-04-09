import AppKit

enum NSAlertPrompt {
    /// Shows a modal alert with a text field for name input.
    /// Returns the trimmed input, or `nil` if the user cancelled.
    static func promptForName(
        title: String,
        prompt: String,
        initialValue: String = ""
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = initialValue
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Shows a destructive confirmation alert. Default button is Cancel.
    /// Returns `true` if the user confirmed.
    static func confirmDestructive(
        title: String,
        message: String,
        confirmButtonTitle: String = "Delete"
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: confirmButtonTitle)

        // Make Cancel (first button) the default
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""

        return alert.runModal() == .alertSecondButtonReturn
    }
}
