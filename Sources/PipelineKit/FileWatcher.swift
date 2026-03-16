import CoreServices
import Foundation

/// FSEvents-based directory watcher for `.hootty/pipeline/` changes.
public class FileWatcher {
    private let path: String
    private var stream: FSEventStreamRef?
    private let queue: DispatchQueue
    private var callback: (([String]) -> Void)?
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval

    public init(path: String, debounceInterval: TimeInterval = 0.3,
                queue: DispatchQueue = DispatchQueue(label: "pipeline.filewatcher")) {
        self.path = path
        self.debounceInterval = debounceInterval
        self.queue = queue
    }

    deinit {
        stop()
    }

    public func start(callback: @escaping ([String]) -> Void) {
        self.callback = callback

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [path] as CFArray

        stream = FSEventStreamCreate(
            nil,
            fileWatcherCallback,
            &context,
            pathsToWatch,
            FSEventsGetCurrentEventId(),
            debounceInterval,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )

        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        debounceWorkItem?.cancel()
    }

    /// Called by the FSEvents C callback
    fileprivate func handleRawEvents(_ paths: [String]) {
        // Filter out .state.lock, .daemon.pid, pipeline.sock — internal files
        let relevant = paths.filter { path in
            let name = (path as NSString).lastPathComponent
            return name != ".state.lock" && name != ".daemon.pid" && name != "pipeline.sock"
        }

        guard !relevant.isEmpty else { return }

        // Debounce: coalesce rapid changes into a single callback
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.callback?(relevant)
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}

/// C callback for FSEvents — must be a free function
private func fileWatcherCallback(
    _: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _: UnsafePointer<FSEventStreamEventFlags>,
    _: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

    // eventPaths is a C array of C strings (without kFSEventStreamCreateFlagUseCFTypes)
    let cPaths = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
    var paths: [String] = []
    for i in 0 ..< numEvents {
        paths.append(String(cString: cPaths[i]))
    }

    watcher.handleRawEvents(paths)
}
