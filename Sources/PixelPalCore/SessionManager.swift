import Foundation

public enum SessionStatus: String, Codable {
    case idle
    case running
    case error
    case stopped
}

public struct AgentSession: Identifiable, Codable {
    public let id: UUID
    public var provider: String           // "claude-code", "codex", "aider"
    public var workspace: String          // directory path
    public var name: String               // display name (auto-generated or user-set)
    public var status: SessionStatus
    public var isRemote: Bool
    public var remoteURL: String?
    public var startedAt: Date
    public var lastHeartbeat: Date
    public var restartCount: Int
    public var pid: Int32?

    public var elapsedMinutes: Int {
        Int(Date().timeIntervalSince(startedAt) / 60)
    }
}

@MainActor
public final class SessionManager: ObservableObject {
    @Published public private(set) var sessions: [AgentSession] = []

    private let maxRestarts = 3
    private var healthCheckTimer: Timer?
    private let persistencePath: String

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pixelpalDir = appSupport.appendingPathComponent("PixelPal", isDirectory: true)
        try? FileManager.default.createDirectory(at: pixelpalDir, withIntermediateDirectories: true)
        persistencePath = pixelpalDir.appendingPathComponent("sessions.json").path

        loadSessions()
        startHealthCheck()
    }

    // MARK: - Session lifecycle

    public func createSession(provider: String, workspace: String, remote: Bool = false) {
        let session = AgentSession(
            id: UUID(),
            provider: provider,
            workspace: workspace,
            name: nameForWorkspace(workspace),
            status: .idle,
            isRemote: remote,
            remoteURL: nil,
            startedAt: Date(),
            lastHeartbeat: Date(),
            restartCount: 0,
            pid: nil
        )
        sessions.append(session)
        spawnProcess(for: sessions.count - 1)
        saveSessions()
    }

    public func stopSession(_ id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        killProcess(at: idx)
        sessions[idx].status = .stopped
        saveSessions()
    }

    public func removeSession(_ id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        killProcess(at: idx)
        sessions.remove(at: idx)
        saveSessions()
    }

    // MARK: - Process management

    private func spawnProcess(for index: Int) {
        guard index < sessions.count else { return }
        let session = sessions[index]

        guard let adapter = ProviderRegistry.adapter(for: session.provider) else {
            print("[PixelPal] Unknown provider: \(session.provider)")
            sessions[index].status = .error
            return
        }

        let process = adapter.buildProcess(workspace: session.workspace, remote: session.isRemote)

        // Redirect stdout/stderr to /dev/null for background sessions
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let sessionId = session.id
        process.terminationHandler = { proc in
            let exitCode = proc.terminationStatus
            Task { @MainActor [weak self] in
                self?.handleTermination(sessionId: sessionId, exitCode: exitCode)
            }
        }

        do {
            try process.run()
            sessions[index].pid = process.processIdentifier
            sessions[index].status = .running
            sessions[index].lastHeartbeat = Date()
            saveSessions()
            print("[PixelPal] Spawned \(session.provider) (PID \(process.processIdentifier)) in \(session.workspace)")
        } catch {
            print("[PixelPal] Failed to spawn \(session.provider): \(error)")
            sessions[index].status = .error
        }
    }

    private func killProcess(at index: Int) {
        guard let pid = sessions[index].pid, pid > 0 else { return }
        kill(pid, SIGTERM)
        sessions[index].pid = nil
    }

    private func handleTermination(sessionId: UUID, exitCode: Int32) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        if exitCode == 0 {
            sessions[idx].status = .stopped
            print("[PixelPal] Session \(sessions[idx].name) completed normally")
        } else if sessions[idx].restartCount < maxRestarts {
            sessions[idx].restartCount += 1
            sessions[idx].status = .error
            print("[PixelPal] Session \(sessions[idx].name) crashed (exit \(exitCode)), restarting (\(sessions[idx].restartCount)/\(maxRestarts))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.spawnProcess(for: idx)
            }
        } else {
            sessions[idx].status = .error
            sessions[idx].pid = nil
            print("[PixelPal] Session \(sessions[idx].name) exceeded max restarts")
        }
        saveSessions()
    }

    // MARK: - Health check

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.checkHealth()
            }
        }
    }

    private func checkHealth() {
        for i in sessions.indices {
            guard let pid = sessions[i].pid, sessions[i].status == .running else { continue }
            // Check if process is still alive
            if kill(pid, 0) != 0 {
                handleTermination(sessionId: sessions[i].id, exitCode: -1)
            } else {
                sessions[i].lastHeartbeat = Date()
            }
        }
    }

    // MARK: - Remote detection

    func detectRemoteStatus() {
        for i in sessions.indices {
            guard let pid = sessions[i].pid else { continue }
            // Check if process was launched with --remote by reading /proc or ps
            let checkProcess = Process()
            checkProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
            checkProcess.arguments = ["-p", "\(pid)", "-o", "args="]
            let pipe = Pipe()
            checkProcess.standardOutput = pipe
            try? checkProcess.run()
            checkProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let args = String(data: data, encoding: .utf8) {
                sessions[i].isRemote = args.contains("--remote")
            }
        }
    }

    // MARK: - Aggregate state for character

    public var aggregateState: CharacterState {
        if sessions.isEmpty { return .idle }
        if sessions.contains(where: { $0.status == .error }) { return .comfort }
        if sessions.contains(where: { $0.status == .running }) { return .working }
        return .idle
    }

    // MARK: - Persistence

    private func saveSessions() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: URL(fileURLWithPath: persistencePath))
        }
    }

    private func loadSessions() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: persistencePath)) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([AgentSession].self, from: data) {
            // Mark all sessions as stopped on load (processes died with app restart)
            sessions = loaded.map { session in
                var s = session
                s.status = .stopped
                s.pid = nil
                return s
            }
        }
    }

    // MARK: - Helpers

    private func nameForWorkspace(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
