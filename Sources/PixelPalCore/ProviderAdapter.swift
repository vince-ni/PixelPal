import Foundation

/// Protocol for AI tool provider adapters.
/// Each provider (Claude Code, Codex, Aider) implements this to handle
/// feature detection and output-line parsing. PixelPal observes the user's
/// own terminal sessions — no process is ever spawned by the app itself.
public protocol ProviderAdapter {
    /// Unique identifier (e.g. "claude-code", "codex", "aider")
    var id: String { get }

    /// Display name for UI
    var displayName: String { get }

    /// Whether the tool is installed on this system
    var isInstalled: Bool { get }

    /// Whether this provider supports native remote (e.g. `claude --remote`).
    /// Used by the UI to decorate session rows with a remote-capable hint.
    var supportsNativeRemote: Bool { get }

    /// Parse a line of stdout for events this provider emits.
    /// Returns nil if the line isn't a recognized event.
    func parseOutput(_ line: String) -> ProviderEvent?
}

/// Events that a provider can emit through its output
public enum ProviderEvent {
    case taskStarted(description: String)
    case taskCompleted(exitCode: Int)
    case needsAttention(message: String)
    case remoteURL(String)
}

// MARK: - Provider Registry

/// Central registry of all available providers.
/// Detects installed tools and provides adapters.
public struct ProviderRegistry {
    public static let all: [ProviderAdapter] = [
        ClaudeCodeAdapter(),
        CodexAdapter(),
        AiderAdapter()
    ]

    /// Only providers that are actually installed
    public static var installed: [ProviderAdapter] {
        all.filter { $0.isInstalled }
    }

    /// Look up adapter by ID
    public static func adapter(for id: String) -> ProviderAdapter? {
        all.first { $0.id == id }
    }
}
