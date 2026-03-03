import Foundation

@Observable
final class PTYSession {
    private(set) var segments: [StyledSegment] = []
    private(set) var isRunning = false

    private var process: PTYProcess?
    private var dispatchIO: DispatchIO?
    private let parser = ANSIParser()
    private let readQueue = DispatchQueue(label: "com.soel.klaude.pty-read", qos: .userInteractive)

    func start(command: String = "/bin/zsh", workingDirectory: String? = nil) {
        guard !isRunning else { return }

        do {
            let dir = workingDirectory ?? FileManager.default.currentDirectoryPath
            let proc = try PTYProcess.spawn(command: command, workingDirectory: dir)
            self.process = proc
            self.isRunning = true
            startReading(fd: proc.masterFD)
            monitorChild(pid: proc.pid)
        } catch {
            appendError("Failed to start: \(error.localizedDescription)")
        }
    }

    func send(_ string: String) {
        guard let proc = process, isRunning else { return }
        let bytes = Array(string.utf8)
        readQueue.async {
            bytes.withUnsafeBufferPointer { buf in
                var written = 0
                while written < buf.count {
                    let result = Darwin.write(proc.masterFD, buf.baseAddress! + written, buf.count - written)
                    if result <= 0 { break }
                    written += result
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        dispatchIO?.close(flags: .stop)
        dispatchIO = nil

        if let proc = process {
            kill(proc.pid, SIGTERM)
            process = nil
        }
    }

    private func startReading(fd: Int32) {
        let io = DispatchIO(
            type: .stream,
            fileDescriptor: fd,
            queue: readQueue,
            cleanupHandler: { _ in
                close(fd)
            }
        )
        io.setLimit(lowWater: 1)
        self.dispatchIO = io

        io.read(offset: 0, length: .max, queue: readQueue) { [weak self] _, data, _ in
            guard let self, let data, !data.isEmpty else { return }

            let text = String(decoding: data, as: UTF8.self)
            let newSegments = self.parser.parse(text)
            if !newSegments.isEmpty {
                DispatchQueue.main.async {
                    self.segments.append(contentsOf: newSegments)
                }
            }
        }
    }

    /// Sole reaper for the child process. Calls stop() on main queue when child exits.
    private func monitorChild(pid: pid_t) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            DispatchQueue.main.async {
                self?.stop()
            }
        }
    }

    private func appendError(_ message: String) {
        segments.append(StyledSegment(
            text: "[Error] \(message)\n",
            style: ANSIStyle(foreground: .standard(1))
        ))
    }
}
