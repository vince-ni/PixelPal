import Foundation

/// Protocol for AI tool provider adapters.
/// Each provider (Claude Code, Codex, Aider) implements this to handle
/// tool-specific spawn arguments, output parsing, and feature detection.
public protocol ProviderAdapter {
    /// Unique identifier (e.g. "claude-code", "codex", "aider")
    var id: String { get }

    /// Display name for UI
    var displayName: String { get }

    /// Whether the tool is installed on this system
    var isInstalled: Bool { get }

    /// Build the Process for spawning this tool.
    /// - Parameters:
    ///   - workspace: working directory
    ///   - remote: whether to enable remote access
    /// - Returns: configured Process ready to run
    func buildProcess(workspace: String, remote: Bool) -> Process

    /// Whether this provider supports native remote (e.g. claude --remote)
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
