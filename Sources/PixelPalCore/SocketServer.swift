import Foundation

public final class SocketServer {
    private let socketPath: String
    private var fileHandle: FileHandle?
    private var serverSocket: Int32 = -1
    private var running = false
    public let onEvent: @Sendable (ShellEvent) -> Void

    public init(onEvent: @escaping @Sendable (ShellEvent) -> Void) {
        let tmpDir = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"]
            ?? ProcessInfo.processInfo.environment["TMPDIR"]
            ?? "/tmp"
        self.socketPath = (tmpDir as NSString).appendingPathComponent("pixelpal.sock")
        self.onEvent = onEvent
    }

    public func start() {
        cleanup()

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("[PixelPal] Failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            print("[PixelPal] Socket path too long")
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() { dest[i] = byte }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            print("[PixelPal] Bind failed: \(String(cString: strerror(errno)))")
            return
        }

        // Allow other users (shell hooks) to connect
        chmod(socketPath, 0o666)

        guard listen(serverSocket, 5) == 0 else {
            print("[PixelPal] Listen failed")
            return
        }

        running = true
        print("[PixelPal] Listening on \(socketPath)")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        running = false
        if serverSocket >= 0 { close(serverSocket); serverSocket = -1 }
        cleanup()
    }

    private func cleanup() {
        unlink(socketPath)
    }

    private func acceptLoop() {
        while running {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverSocket, sockPtr, &clientLen)
                }
            }
            guard clientFd >= 0 else { continue }

            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handleClient(clientFd)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            data.append(contentsOf: buffer[0..<bytesRead])
        }

        guard !data.isEmpty else { return }

        // Parse newline-delimited JSON messages
        let text = String(data: data, encoding: .utf8) ?? ""
        for line in text.components(separatedBy: "\n") where !line.isEmpty {
            if let event = parseEvent(line) {
                onEvent(event)
            }
        }
    }

    private func parseEvent(_ json: String) -> ShellEvent? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kindStr = dict["e"] as? String,
              let kind = ShellEvent.Kind(rawValue: kindStr) else {
            return nil
        }

        return ShellEvent(
            kind: kind,
            timestamp: dict["t"] as? TimeInterval ?? Date().timeIntervalSince1970,
            command: dict["cmd"] as? String,
            exitCode: dict["exit"] as? Int,
            duration: dict["dur"] as? Int,
            pwd: dict["pwd"] as? String,
            gitBranch: dict["git"] as? String
        )
    }

    deinit { stop() }
}
