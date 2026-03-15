import Foundation

/// Watches `.git/HEAD` files for changes using DispatchSource.
/// One watcher per canonical repo root, shared across all panes in that repo.
/// Detects branch switches that don't trigger pwd change events.
final class GitHEADWatcher {
    private struct WatchEntry {
        var dirSource: DispatchSourceFileSystemObject?
        var fileSource: DispatchSourceFileSystemObject?
        var dirFD: Int32 = -1
        var fileFD: Int32 = -1
        var gitCommonDir: String
    }

    private var entries: [String: WatchEntry] = [:]
    private var onChange: ((String) -> Void)?

    deinit {
        stopAll()
    }

    /// Set the callback invoked when any watched HEAD file changes.
    /// The parameter is the canonical repo root path.
    func setOnChange(_ handler: @escaping (String) -> Void) {
        onChange = handler
    }

    /// Repo roots currently being watched.
    var watchedRepoRoots: Set<String> {
        Set(entries.keys)
    }

    /// Start watching `.git/HEAD` for the given repo.
    /// `gitCommonDir` is the `.git` common directory (from `git rev-parse --git-common-dir`).
    /// Does nothing if already watching this root.
    func startWatching(repoRoot: String, gitCommonDir: String) {
        guard entries[repoRoot] == nil else { return }
        var entry = WatchEntry(gitCommonDir: gitCommonDir)

        let headPath = (gitCommonDir as NSString).appendingPathComponent("HEAD")

        // Watch the .git directory for file creation (atomic HEAD replacement)
        let dirFD = open(gitCommonDir, O_EVTONLY)
        if dirFD >= 0 {
            entry.dirFD = dirFD
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFD,
                eventMask: [.write, .rename],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.handleDirectoryChange(repoRoot: repoRoot, headPath: headPath)
            }
            source.setCancelHandler { close(dirFD) }
            source.resume()
            entry.dirSource = source
        }

        // Watch the HEAD file directly (if it exists)
        watchHEADFile(repoRoot: repoRoot, path: headPath, entry: &entry)

        entries[repoRoot] = entry
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

    private func handleDirectoryChange(repoRoot: String, headPath: String) {
        // Re-establish HEAD file watch if it was lost (atomic replacement)
        if entries[repoRoot]?.fileFD == -1 || entries[repoRoot]?.fileSource == nil {
            if FileManager.default.fileExists(atPath: headPath) {
                if var entry = entries[repoRoot] {
                    watchHEADFile(repoRoot: repoRoot, path: headPath, entry: &entry)
                    entries[repoRoot] = entry
                }
            }
        }
        onChange?(repoRoot)
    }

    private func watchHEADFile(repoRoot: String, path: String, entry: inout WatchEntry) {
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
            // If file was deleted/renamed (atomic replacement), clear file watch
            // and rely on directory watch to re-establish
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
