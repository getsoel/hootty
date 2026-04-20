import Foundation

/// Pure helpers for comparing release version strings component-wise.
///
/// Lives in `HoottyCore` so the logic is unit-testable (the `Hootty`
/// executable target has no test target). `UpdateChecker` delegates
/// here for the actual comparison.
public enum VersionCompare {
    /// Parses a version string into an array of integer components.
    ///
    /// Strips a leading `v`, splits on `.`, and maps each component to
    /// `Int` (treating any non-numeric component as `0`).
    public static func parseVersion(_ string: String) -> [Int] {
        var trimmed = Substring(string)
        if trimmed.first == "v" {
            trimmed = trimmed.dropFirst()
        }
        return trimmed.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// Returns `true` iff `remote` is strictly greater than `local` under
    /// component-wise integer comparison. Shorter sequences are padded
    /// with zeros so `0.3` and `0.3.0` compare equal.
    public static func isNewer(remote: String, than local: String) -> Bool {
        let remoteParts = parseVersion(remote)
        let localParts = parseVersion(local)
        let count = max(remoteParts.count, localParts.count)
        for index in 0 ..< count {
            let remoteComponent = index < remoteParts.count ? remoteParts[index] : 0
            let localComponent = index < localParts.count ? localParts[index] : 0
            if remoteComponent > localComponent { return true }
            if remoteComponent < localComponent { return false }
        }
        return false
    }
}
