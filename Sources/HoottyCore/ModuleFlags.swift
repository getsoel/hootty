public struct ModuleFlags: Equatable, Sendable {
    public let spec: Bool

    public init(spec: Bool = false) {
        self.spec = spec
    }
}
