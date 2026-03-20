public struct ModuleFlags: Equatable, Sendable {
    public let opsx: Bool

    public init(opsx: Bool = false) {
        self.opsx = opsx
    }
}
