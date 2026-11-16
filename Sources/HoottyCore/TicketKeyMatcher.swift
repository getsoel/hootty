import Foundation

/// Extracts a Jira-style issue key (e.g. "ED-516") from a git branch name.
///
/// A key must start a `/`-separated branch segment and be followed by the end
/// of the segment, `-`, or `_`: `feat/ed-372-wireframes` and `ED-516-synthetics`
/// match, `andrew-ED-516` and `release-0.1.1` do not.
///
/// With no project keys configured, only all-caps keys match, since lowercase
/// branch names are full of false positives (`node-26-upgrade`, `dev-5-env`).
/// With project keys configured (`hootty-jira-projects = ED, VIDEO`), only those
/// projects match, in any case.
public struct TicketKeyMatcher: Sendable, Equatable {
    public static let projectsConfigKey = "hootty-jira-projects"
    public static let urlConfigKey = "hootty-jira-url"

    /// Uppercased project keys. Empty means "any all-caps key".
    public let projectKeys: Set<String>
    /// Jira site root, e.g. `https://example.atlassian.net`.
    public let jiraURL: URL?

    public init(projectKeys: Set<String> = [], jiraURL: URL? = nil) {
        self.projectKeys = Set(projectKeys.map { $0.uppercased() })
        self.jiraURL = jiraURL
    }

    /// Builds a matcher from raw config values: a comma/space separated project
    /// list and a Jira site URL.
    public init(projectsConfig: String?, urlConfig: String?) {
        let keys = (projectsConfig ?? "")
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map(String.init)
        let url = urlConfig.flatMap { raw -> URL? in
            guard let url = URL(string: raw), url.scheme != nil, url.host != nil else { return nil }
            return url
        }
        self.init(projectKeys: Set(keys), jiraURL: url)
    }

    /// The first ticket key in `branch`, uppercased, or nil.
    public func ticketKey(inBranch branch: String) -> String? {
        for segment in branch.split(separator: "/") {
            if let key = ticketKey(atStartOf: segment) {
                return key
            }
        }
        return nil
    }

    /// `<jira-url>/browse/<KEY>`, or nil when no Jira URL is configured.
    public func browseURL(for key: String) -> URL? {
        jiraURL?.appendingPathComponent("browse").appendingPathComponent(key)
    }

    private func ticketKey(atStartOf segment: Substring) -> String? {
        guard let dash = segment.firstIndex(of: "-") else { return nil }
        let project = segment[..<dash]
        guard let first = project.first, first.isASCII, first.isLetter,
              project.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }

        let afterDash = segment[segment.index(after: dash)...]
        let number = afterDash.prefix { $0.isASCII && $0.isNumber }
        guard !number.isEmpty else { return nil }
        if let terminator = afterDash.dropFirst(number.count).first,
           terminator != "-", terminator != "_" {
            return nil
        }

        let upper = project.uppercased()
        if projectKeys.isEmpty {
            guard project == upper else { return nil }
        } else {
            guard projectKeys.contains(upper) else { return nil }
        }
        return "\(upper)-\(number)"
    }
}
