import AppKit

extension NSPasteboard {
    func copyString(_ string: String) {
        clearContents()
        setString(string, forType: .string)
    }
}
