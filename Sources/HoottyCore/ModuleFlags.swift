public struct ModuleFlags: Equatable, Sendable {
    public let workshop: Bool

    public init(workshop: Bool = false) {
        self.workshop = workshop
    }
}
