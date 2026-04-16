import Foundation

public enum SessionStatus: String, Codable {
    case idle
    case running
    case error
    case stopped
}

/// A record of AI-agent activity observed on this machine. PixelPal does not
/// spawn or manage these processes — sessions here reflect what the shell
/// hook and provider adapters notice in the user's own terminals.
public struct AgentSession: Identifiable, Codable {
    public let id: UUID
    public var provider: String           // "claude-code", "codex", "aider"
    public var workspace: String          // directory path
    public var name: String               // display name
    public var status: SessionStatus
    public var isRemote: Bool
    public var remoteURL: String?
    public var startedAt: Date

    public init(
        id: UUID = UUID(),
        provider: String,
        workspace: String,
        name: String,
        status: SessionStatus = .running,
        isRemote: Bool = false,
        remoteURL: String? = nil,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.workspace = workspace
        self.name = name
        self.status = status
        self.isRemote = isRemote
        self.remoteURL = remoteURL
        self.startedAt = startedAt
    }

    public var elapsedMinutes: Int {
        Int(Date().timeIntervalSince(startedAt) / 60)
    }
}

/// Observational session store. The user runs `claude` / `codex` / `aider`
/// in their own terminal; the entry points below accept the shell-hook
/// events that will surface those sessions.
///
/// ## Current wiring status
///
/// The entry points are **API placeholders**. No call site in the app
/// currently invokes them — `main.swift` routes socket events to
/// `StateMachine` and `WorkPatternStore` only. As a result the Sessions
/// tab today permanently reflects an empty list, and the UI deliberately
/// uses that empty state to show an onboarding card rather than attempting
/// to represent every observed command as a session row.
///
/// Wiring the entry points to socket events (with correct provider
/// detection, workspace tracking, and concurrent-session correlation via
/// `workspace + startedAt` fingerprints) is scheduled as a separate
/// Phase 3 piece of work. Until then this class intentionally stores no
/// state and persists nothing — doing so would risk showing stale or
/// mis-attributed rows.
///
/// Entry points reserved for Phase 3:
///   - `recordSessionStarted` — shell hook saw an AI command begin
///   - `recordRemoteURL`      — provider output carried a remote URL
///   - `recordSessionEnded`   — shell hook saw the AI session end
///   - `dismissSession`       — user clicked the dismiss button on a row
@MainActor
public final class SessionManager: ObservableObject {
    @Published public private(set) var sessions: [AgentSession] = []

    public init() {}

    // MARK: - Observational entry points (Phase 3 — currently unwired)

    /// Shell hook observed an AI command begin. Creates a running record.
    public func recordSessionStarted(provider: String, workspace: String) {
        let session = AgentSession(
            provider: provider,
            workspace: workspace,
            name: URL(fileURLWithPath: workspace).lastPathComponent
        )
        sessions.append(session)
    }

    /// Attach a remote URL to the most recent matching running session.
    /// Phase 3 will replace the last-match heuristic with a
    /// `workspace + startedAt` fingerprint to handle concurrent sessions.
    public func recordRemoteURL(_ url: String, provider: String) {
        guard let idx = sessions.lastIndex(where: { $0.provider == provider && $0.status == .running }) else {
            return
        }
        sessions[idx].remoteURL = url
        sessions[idx].isRemote = true
    }

    /// Mark the most recent running session of the given provider as ended.
    /// Exit code of 0 or nil → stopped; anything else → error. Same
    /// last-match caveat as `recordRemoteURL` applies.
    public func recordSessionEnded(provider: String, exitCode: Int? = nil) {
        guard let idx = sessions.lastIndex(where: { $0.provider == provider && $0.status == .running }) else {
            return
        }
        sessions[idx].status = (exitCode == nil || exitCode == 0) ? .stopped : .error
    }

    /// User clicked the dismiss button on a row — hide it from the list.
    /// UI state only; the underlying terminal session (if still alive) is
    /// unaffected.
    public func dismissSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    // MARK: - Aggregate state for character

    /// Used by the StateMachine to roll up multi-session status into a
    /// single character expression.
    public var aggregateState: CharacterState {
        if sessions.isEmpty { return .idle }
        if sessions.contains(where: { $0.status == .error }) { return .comfort }
        if sessions.contains(where: { $0.status == .running }) { return .working }
        return .idle
    }
}
