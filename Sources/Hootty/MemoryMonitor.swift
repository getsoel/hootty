import Foundation
import HoottyCore

/// Tracks memory usage over time, recording periodic samples.
/// Extracted from ContentView to isolate memory monitoring from UI concerns.
@MainActor
@Observable
final class MemoryMonitor {
    private(set) var memoryMB: Int = 0
    private(set) var samples: [MemorySample] = []
    private var sampleIndex: Int = 0

    private static let maxSamples = 300

    func recordSample(appModel: AppModel) {
        let mb = Self.physicalFootprintMB()
        let panes = appModel.workspaces.reduce(0) { $0 + $1.allPanes.count }
        let surfaces = TerminalSurfaceView.liveCount
        let prevMB = samples.last?.memoryMB

        var sample = MemorySample(
            timestamp: Date(),
            memoryMB: mb,
            paneCount: panes,
            surfaceCount: surfaces
        )
        if let prevMB {
            sample.deltaMB = mb - prevMB
        }

        samples.append(sample)
        if samples.count > Self.maxSamples {
            samples.removeFirst(samples.count - Self.maxSamples)
        }
        memoryMB = mb

        MemoryLogger.record(
            sampleIndex: sampleIndex,
            memoryMB: mb,
            paneCount: panes,
            surfaceCount: surfaces,
            deltaMB: sample.deltaMB
        )
        sampleIndex += 1
    }

    static func physicalFootprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint / 1_048_576)
    }
}
