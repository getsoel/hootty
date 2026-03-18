public struct ModuleFlags: Equatable, Sendable {
    public let pipelines: Bool
    public let macros: Bool

    public init(pipelines: Bool = false, macros: Bool = false) {
        self.pipelines = pipelines
        self.macros = macros
    }
}
