import Foundation
import HoottyCore

/// Watches `.hootty/pipeline/.state.json` files for changes using DispatchSource.
/// One watcher per repo root, shared across all panes in that repo.
final class PipelineWatcher {
    private struct WatchEntry {
        var dirSource: DispatchSourceFileSystemObject?
        var fileSource: DispatchSourceFileSystemObject?
        var dirFD: Int32 = -1
        var fileFD: Int32 = -1
    }

    private var entries: [String: WatchEntry] = [:]
    private var onChange: ((String) -> Void)?

    deinit {
        stopAll()
    }

    /// Set the callback invoked when any watched `.state.json` changes.
    /// The parameter is the repo root path.
    func setOnChange(_ handler: @escaping (String) -> Void) {
        onChange = handler
    }

    /// Start watching `.state.json` in the pipeline directory at the given repo root.
    /// Does nothing if already watching this root.
    func startWatching(repoRoot: String) {
        guard entries[repoRoot] == nil else { return }
        var entry = WatchEntry()

        let pipelineDir = (repoRoot as NSString).appendingPathComponent(PipelineModel.directoryPath)
        let stateFilePath = (pipelineDir as NSString).appendingPathComponent(".state.json")

        // Watch the directory for file creation/deletion
        let dirFD = open(pipelineDir, O_EVTONLY)
        if dirFD >= 0 {
            entry.dirFD = dirFD
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFD,
                eventMask: [.write, .rename],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.handleDirectoryChange(repoRoot: repoRoot, stateFilePath: stateFilePath)
            }
            source.setCancelHandler { close(dirFD) }
            source.resume()
            entry.dirSource = source
        }

        // Watch the state file directly (if it exists)
        watchStateFile(repoRoot: repoRoot, path: stateFilePath, entry: &entry)

        entries[repoRoot] = entry

        // Fire initial read
        onChange?(repoRoot)
    }

    /// Stop watching a specific repo root.
    func stopWatching(repoRoot: String) {
        guard var entry = entries.removeValue(forKey: repoRoot) else { return }
        cancelEntry(&entry)
    }

    /// Stop all watchers.
    func stopAll() {
        for key in entries.keys {
            if var entry = entries[key] {
                cancelEntry(&entry)
            }
        }
        entries.removeAll()
    }

    // MARK: - Private

    private func handleDirectoryChange(repoRoot: String, stateFilePath: String) {
        // The directory changed — re-check if .state.json exists and re-watch if needed
        if entries[repoRoot]?.fileFD == -1 || entries[repoRoot]?.fileSource == nil {
            if FileManager.default.fileExists(atPath: stateFilePath) {
                if var entry = entries[repoRoot] {
                    watchStateFile(repoRoot: repoRoot, path: stateFilePath, entry: &entry)
                    entries[repoRoot] = entry
                }
            }
        }
        onChange?(repoRoot)
    }

    private func watchStateFile(repoRoot: String, path: String, entry: inout WatchEntry) {
        // Cancel existing file watch if any
        entry.fileSource?.cancel()
        entry.fileSource = nil
        if entry.fileFD >= 0 {
            close(entry.fileFD)
            entry.fileFD = -1
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        entry.fileFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            // If file was deleted/renamed, clear file watch and rely on directory watch to re-establish
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) {
                if var entry = self?.entries[repoRoot] {
                    entry.fileSource?.cancel()
                    entry.fileSource = nil
                    if entry.fileFD >= 0 {
                        close(entry.fileFD)
                        entry.fileFD = -1
                    }
                    self?.entries[repoRoot] = entry
                }
            }
            self?.onChange?(repoRoot)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        entry.fileSource = source
    }

    private func cancelEntry(_ entry: inout WatchEntry) {
        entry.fileSource?.cancel()
        entry.fileSource = nil
        entry.dirSource?.cancel()
        entry.dirSource = nil
        // File descriptors closed by cancel handlers
        entry.fileFD = -1
        entry.dirFD = -1
    }
}
