import Foundation
import Testing
@testable import HoottyCore

struct TicketKeyMatcherTests {
    private let unconfigured = TicketKeyMatcher()
    private let configured = TicketKeyMatcher(projectsConfig: "ED, video", urlConfig: nil)

    @Test func allCapsKeysMatchWithoutConfig() {
        #expect(unconfigured.ticketKey(inBranch: "ED-516-synthetics") == "ED-516")
        #expect(unconfigured.ticketKey(inBranch: "feat/ED-490-viewer-download") == "ED-490")
        #expect(unconfigured.ticketKey(inBranch: "ED-516") == "ED-516")
        #expect(unconfigured.ticketKey(inBranch: "fix/VIDEO2-7_hotfix") == "VIDEO2-7")
    }

    @Test func lowercaseKeysNeedConfiguredProject() {
        #expect(unconfigured.ticketKey(inBranch: "feat/ed-372-wireframes") == nil)
        #expect(configured.ticketKey(inBranch: "feat/ed-372-wireframes") == "ED-372")
        #expect(configured.ticketKey(inBranch: "backup/video-12") == "VIDEO-12")
    }

    @Test func configuredProjectsExcludeOtherKeys() {
        #expect(configured.ticketKey(inBranch: "SAAS-9-thing") == nil)
    }

    /// Real branch names that look like keys but aren't.
    @Test func nonTicketBranchesDoNotMatch() {
        let branches = [
            "main", "chore/node-26-upgrade", "feat/dev-5-env", "backup/main-with-165-b246e3ea",
            "backup/release-0.1.1-pre-rebuild", "chore/zod-4.6.5", "eval/assumptions-form-2",
            "andrew-ED-516", "ED-", "-516", "ED-516x", "2FA-1"
        ]
        for branch in branches {
            #expect(unconfigured.ticketKey(inBranch: branch) == nil, "\(branch)")
            #expect(configured.ticketKey(inBranch: branch) == nil, "\(branch)")
        }
    }

    @Test func browseURLRequiresConfiguredSite() {
        #expect(unconfigured.browseURL(for: "ED-516") == nil)
        let matcher = TicketKeyMatcher(projectsConfig: nil, urlConfig: "https://lively-video.atlassian.net")
        #expect(matcher.browseURL(for: "ED-516")?.absoluteString == "https://lively-video.atlassian.net/browse/ED-516")
        #expect(TicketKeyMatcher(projectsConfig: nil, urlConfig: "not a url").jiraURL == nil)
    }
}
