import Foundation
import HoottyCore

/// Watches `spec/` directories for changes using DispatchSource.
/// Monitors `spec/`, `spec/changes/`, and `spec/archive/` subdirectories
/// to detect new/removed/archived changes. One watcher per repo root.
@MainActor
final class SpecWatcher {
    private struct WatchEntry {
        var sources: [DispatchSourceFileSystemObject] = []
    }

    private var entries: [String: WatchEntry] = [:]
    private var onChange: ((String) -> Void)?

    /// Repo roots currently being watched.
    var watchedRepoRoots: Set<String> {
        Set(entries.keys)
    }

    deinit {
        for entry in entries.values {
            for source in entry.sources {
                source.cancel()
            }
        }
    }

    /// Set the callback invoked when any watched `spec/` directory changes.
    /// The parameter is the repo root path.
    func setOnChange(_ handler: @escaping (String) -> Void) {
        onChange = handler
    }

    /// Start watching the `spec/` and `.hootty/claims/` directories at the given repo root.
    /// Does nothing if already watching this root.
    func startWatching(repoRoot: String) {
        guard entries[repoRoot] == nil else { return }

        let specDir = (repoRoot as NSString).appendingPathComponent(SpecModel.directoryPath)
        let changesDir = (specDir as NSString).appendingPathComponent("changes")
        let archiveDir = (specDir as NSString).appendingPathComponent("archive")
        let claimsDir = (repoRoot as NSString).appendingPathComponent(SpecModel.claimsPath)

        var entry = WatchEntry()
        for dir in [specDir, changesDir, archiveDir, claimsDir] {
            if let source = makeSource(dir: dir, repoRoot: repoRoot) {
                entry.sources.append(source)
            }
        }

        entries[repoRoot] = entry

        // Fire initial read
        onChange?(repoRoot)
    }

    /// Stop watching a specific repo root.
    func stopWatching(repoRoot: String) {
        guard let entry = entries.removeValue(forKey: repoRoot) else { return }
        for source in entry.sources {
            source.cancel()
        }
    }

    /// Stop all watchers.
    func stopAll() {
        for entry in entries.values {
            for source in entry.sources {
                source.cancel()
            }
        }
        entries.removeAll()
    }

    // MARK: - Private

    private func makeSource(dir: String, repoRoot: String) -> DispatchSourceFileSystemObject? {
        let fd = open(dir, O_EVTONLY)
        guard fd >= 0 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.onChange?(repoRoot)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }
}
