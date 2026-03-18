import Foundation

/// Tracks macro execution state per pane.
@MainActor
@Observable
public final class MacroRunner {
    /// Active macro execution, keyed by pane ID. At most one macro per pane.
    private var activeMacros: [UUID: MacroExecution] = [:]

    public init() {}

    /// Snapshot of a running macro's state for UI display.
    public struct MacroProgress: Sendable {
        public let macroName: String
        public let currentStep: Int // 0-based
        public let totalSteps: Int
        public let currentStepText: String
        public let isComplete: Bool
    }

    /// Internal execution state.
    private struct MacroExecution {
        let macro: Macro
        var currentStep: Int // 0-based, next step to execute
        var isComplete: Bool
    }

    // MARK: - Lifecycle

    /// Start a macro on a pane. Returns the first step text to inject, or nil if macro has no steps.
    public func start(macro: Macro, paneID: UUID) -> String? {
        guard !macro.steps.isEmpty else { return nil }
        activeMacros[paneID] = MacroExecution(macro: macro, currentStep: 0, isComplete: false)
        return macro.steps[0]
    }

    /// Signal that the current step completed. Returns the next step text to inject, or nil if done.
    public func stepCompleted(paneID: UUID) -> String? {
        guard var execution = activeMacros[paneID], !execution.isComplete else { return nil }

        let nextStep = execution.currentStep + 1
        if nextStep >= execution.macro.steps.count {
            execution.isComplete = true
            activeMacros[paneID] = execution
            return nil
        }

        execution.currentStep = nextStep
        activeMacros[paneID] = execution
        return execution.macro.steps[nextStep]
    }

    /// Remove a macro from a pane (cancel running or dismiss completed).
    public func remove(paneID: UUID) {
        activeMacros.removeValue(forKey: paneID)
    }

    /// Remove all active macros (used on workspace reset).
    public func removeAll() {
        activeMacros.removeAll()
    }

    /// Check if a pane has an active (running or completed) macro.
    public func isActive(paneID: UUID) -> Bool {
        activeMacros[paneID] != nil
    }

    /// Get the current progress for a pane's macro.
    public func progress(paneID: UUID) -> MacroProgress? {
        guard let execution = activeMacros[paneID] else { return nil }
        return MacroProgress(
            macroName: execution.macro.name,
            currentStep: execution.currentStep,
            totalSteps: execution.macro.steps.count,
            currentStepText: execution.macro.steps[execution.currentStep],
            isComplete: execution.isComplete
        )
    }
}
