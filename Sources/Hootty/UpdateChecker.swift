import AppKit
import Foundation
import HoottyCore

@MainActor
@Observable
final class UpdateChecker {
    var latestVersion: String?
    var justCopied: Bool = false

    var isOutdated: Bool {
        guard Self.readOptedIn(), let latestVersion, let local = Self.localVersion else { return false }
        return VersionCompare.isNewer(remote: latestVersion, than: local)
    }

    private nonisolated static let repoSlug = "getsoel/hootty"
    private nonisolated static let releasesURL = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest")!
    private nonisolated static let throttleWindow: TimeInterval = 14400
    private nonisolated static let requestTimeout: TimeInterval = 10
    private nonisolated static let copyFeedbackDuration: Duration = .milliseconds(1200)
    private nonisolated static let brewUpgradeCommand = "brew upgrade --cask hootty"

    private nonisolated static let lastCheckedAtKey = "com.soel.hootty.updateCheck.lastCheckedAt"
    private nonisolated static let lastSeenVersionKey = "com.soel.hootty.updateCheck.lastSeenVersion"
    nonisolated static let optedInKey = "com.soel.hootty.updateCheck.optedIn"

    @ObservationIgnored private var copyResetTask: Task<Void, Never>?

    func copyBrewCommand() {
        NSPasteboard.general.copyString(Self.brewUpgradeCommand)

        justCopied = true
        copyResetTask?.cancel()
        copyResetTask = Task { [weak self] in
            try? await Task.sleep(for: Self.copyFeedbackDuration)
            guard !Task.isCancelled else { return }
            self?.justCopied = false
        }
    }

    func check() async {
        guard Self.isInstalledBuild() else { return }
        guard Self.readOptedIn() else { return }

        let defaults = UserDefaults.standard
        let now = CFAbsoluteTimeGetCurrent()
        let lastChecked = defaults.double(forKey: Self.lastCheckedAtKey)

        if now - lastChecked < Self.throttleWindow {
            if latestVersion == nil {
                latestVersion = defaults.string(forKey: Self.lastSeenVersionKey)
            }
            return
        }

        var request = URLRequest(url: Self.releasesURL, timeoutInterval: Self.requestTimeout)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200 ..< 300).contains(http.statusCode),
            let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
        else { return }

        defaults.set(now, forKey: Self.lastCheckedAtKey)
        defaults.set(release.tag_name, forKey: Self.lastSeenVersionKey)
        latestVersion = release.tag_name
    }

    /// Absent key defaults to opted-in per requirement `update-check-preferences`.
    private nonisolated static func readOptedIn() -> Bool {
        guard let raw = UserDefaults.standard.object(forKey: optedInKey) as? Bool else { return true }
        return raw
    }

    private nonisolated static func isInstalledBuild() -> Bool {
        let path = Bundle.main.bundleURL.path
        return path.hasPrefix("/Applications/") || path.contains("/Caskroom/")
    }

    private nonisolated static var localVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

private struct GitHubRelease: Decodable {
    let tag_name: String
}
