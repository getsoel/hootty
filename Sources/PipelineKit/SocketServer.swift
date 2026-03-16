import Foundation
#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Unix domain socket server for the pipeline daemon.
/// Protocol: newline-delimited JSON (one JSON object per line, bidirectional).
public class SocketServer {
    public let socketPath: String
    private var serverFD: Int32 = -1
    private var clients: [Int32: ClientState] = [:]
    private let queue = DispatchQueue(label: "pipeline.socket", qos: .userInitiated)
    private var acceptSource: DispatchSourceRead?
    public var onCommand: ((DaemonCommand, Int32) -> Void)?

    private struct ClientState {
        var readSource: DispatchSourceRead?
        var buffer: Data = .init()
    }

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    // MARK: - Lifecycle

    public func start() throws {
        // Remove stale socket file
        unlink(socketPath)

        // Create socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw PipelineError.fileError("Failed to create socket: \(String(cString: strerror(errno)))")
        }

        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(serverFD)
            throw PipelineError.fileError("Socket path too long")
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            for (i, byte) in pathBytes.enumerated() {
                raw.storeBytes(of: Int8(bitPattern: byte), toByteOffset: i, as: Int8.self)
            }
            raw.storeBytes(of: Int8(0), toByteOffset: pathBytes.count, as: Int8.self)
        }

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(serverFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverFD)
            throw PipelineError.fileError("Failed to bind socket: \(String(cString: strerror(errno)))")
        }

        // Listen
        guard listen(serverFD, 16) == 0 else {
            close(serverFD)
            throw PipelineError.fileError("Failed to listen: \(String(cString: strerror(errno)))")
        }

        // Accept connections via GCD
        acceptSource = DispatchSource.makeReadSource(fileDescriptor: serverFD, queue: queue)
        acceptSource?.setEventHandler { [weak self] in
            self?.acceptClient()
        }
        acceptSource?.setCancelHandler { [weak self] in
            if let fd = self?.serverFD, fd >= 0 {
                close(fd)
            }
        }
        acceptSource?.resume()
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil

        // Close all client connections
        queue.sync {
            for (fd, state) in clients {
                state.readSource?.cancel()
                close(fd)
            }
            clients.removeAll()
        }

        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }

        unlink(socketPath)
    }

    // MARK: - Broadcasting

    /// Send an event to all connected clients
    public func broadcast(_ event: PipelineEvent) {
        let data = event.jsonLine()
        queue.async { [weak self] in
            guard let self else { return }
            var disconnected: [Int32] = []
            for fd in clients.keys {
                let result = data.withUnsafeBytes { buf in
                    write(fd, buf.baseAddress!, buf.count)
                }
                if result <= 0 {
                    disconnected.append(fd)
                }
            }
            for fd in disconnected {
                disconnectClient(fd)
            }
        }
    }

    /// Send a response to a specific client
    public func send(_ response: DaemonResponse, to clientFD: Int32) {
        let data = response.jsonLine()
        queue.async {
            data.withUnsafeBytes { buf in
                _ = write(clientFD, buf.baseAddress!, buf.count)
            }
        }
    }

    public var clientCount: Int {
        queue.sync { clients.count }
    }

    // MARK: - Private

    private func acceptClient() {
        let clientFD = accept(serverFD, nil, nil)
        guard clientFD >= 0 else { return }

        // Set non-blocking
        let flags = fcntl(clientFD, F_GETFL)
        _ = fcntl(clientFD, F_SETFL, flags | O_NONBLOCK)

        var state = ClientState()

        // Set up read source for this client
        let readSource = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        readSource.setEventHandler { [weak self] in
            self?.readFromClient(clientFD)
        }
        readSource.setCancelHandler { [weak self] in
            self?.clients.removeValue(forKey: clientFD)
            close(clientFD)
        }

        state.readSource = readSource
        clients[clientFD] = state
        readSource.resume()

        // Send daemon_ready event to new client
        let ready = PipelineEvent.daemonReady()
        let data = ready.jsonLine()
        data.withUnsafeBytes { buf in
            _ = write(clientFD, buf.baseAddress!, buf.count)
        }
    }

    private func readFromClient(_ fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buf, buf.count)

        if bytesRead <= 0 {
            disconnectClient(fd)
            return
        }

        clients[fd]?.buffer.append(contentsOf: buf[0 ..< bytesRead])

        // Process complete lines
        while let state = clients[fd] {
            guard let newlineIdx = state.buffer.firstIndex(of: UInt8(ascii: "\n")) else { break }
            let lineData = Data(state.buffer[state.buffer.startIndex ..< newlineIdx])
            clients[fd]?.buffer = Data(state.buffer[state.buffer.index(after: newlineIdx)...])

            // Parse command
            if let command = try? JSONDecoder().decode(DaemonCommand.self, from: lineData) {
                onCommand?(command, fd)
            }
        }
    }

    private func disconnectClient(_ fd: Int32) {
        clients[fd]?.readSource?.cancel()
        // cancel handler removes from dict and closes fd
    }
}
