import Foundation

/// OpenAI Codex CLI adapter.
/// Codex uses --cwd for workspace and has no native remote support.
public struct CodexAdapter: ProviderAdapter {
    public let id = "codex"
    public let displayName = "Codex CLI"
    public let supportsNativeRemote = false

    public init() {}

    public var isInstalled: Bool {
        which("codex") != nil
    }

    public func buildProcess(workspace: String, remote: Bool) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: workspace)
        process.arguments = ["codex", "--cwd", workspace]
        return process
    }

    public func parseOutput(_ line: String) -> ProviderEvent? {
        // Codex emits structured output we can parse for task events
        if line.contains("Applied") && line.contains("patch") {
            return .taskCompleted(exitCode: 0)
        }
        return nil
    }

    private func which(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
