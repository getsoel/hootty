import Testing
@testable import HoottyCore

struct VersionCompareTests {
    // MARK: - parseVersion

    @Test("parseVersion strips a leading v")
    func stripsLeadingV() {
        #expect(VersionCompare.parseVersion("v0.3.1") == [0, 3, 1])
        #expect(VersionCompare.parseVersion("0.3.1") == [0, 3, 1])
    }

    @Test("parseVersion maps non-numeric components to 0")
    func nonNumericComponentsBecomeZero() {
        #expect(VersionCompare.parseVersion("0.3.beta") == [0, 3, 0])
        #expect(VersionCompare.parseVersion("v1..2") == [1, 2])
    }

    @Test("parseVersion preserves multi-digit components")
    func multiDigitComponents() {
        #expect(VersionCompare.parseVersion("v0.10.0") == [0, 10, 0])
        #expect(VersionCompare.parseVersion("12.34.56") == [12, 34, 56])
    }

    // MARK: - isNewer: numeric compare scenarios from update-check-service

    @Test("remote v0.10.0 is newer than local 0.2.0 (multi-digit ordering)")
    func remoteStrictlyGreaterMultiDigit() {
        #expect(VersionCompare.isNewer(remote: "v0.10.0", than: "0.2.0") == true)
    }

    @Test("remote v0.3.1 equal to local 0.3.1 is not newer")
    func remoteEqualsLocal() {
        #expect(VersionCompare.isNewer(remote: "v0.3.1", than: "0.3.1") == false)
    }

    @Test("local ahead of remote is not newer")
    func localAheadOfRemote() {
        #expect(VersionCompare.isNewer(remote: "v0.3.0", than: "0.3.1") == false)
        #expect(VersionCompare.isNewer(remote: "v0.2.0", than: "0.10.0") == false)
    }

    @Test("leading v on both sides is stripped before comparison")
    func leadingVBothSides() {
        #expect(VersionCompare.isNewer(remote: "v0.4.0", than: "v0.3.9") == true)
        #expect(VersionCompare.isNewer(remote: "v0.3.9", than: "v0.4.0") == false)
    }

    // MARK: - unequal-length version strings

    @Test("shorter remote pads with zeros so 0.3 equals 0.3.0")
    func unequalLengthEqual() {
        #expect(VersionCompare.isNewer(remote: "v0.3", than: "0.3.0") == false)
        #expect(VersionCompare.isNewer(remote: "v0.3.0", than: "0.3") == false)
    }

    @Test("extra trailing component makes remote newer when non-zero")
    func unequalLengthRemoteNewer() {
        #expect(VersionCompare.isNewer(remote: "v0.3.1", than: "0.3") == true)
        #expect(VersionCompare.isNewer(remote: "v1", than: "0.99.99") == true)
    }

    @Test("extra trailing component makes remote older when local is longer and higher")
    func unequalLengthLocalNewer() {
        #expect(VersionCompare.isNewer(remote: "v0.3", than: "0.3.1") == false)
    }
}
