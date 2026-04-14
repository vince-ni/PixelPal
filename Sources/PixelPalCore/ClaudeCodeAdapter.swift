import Foundation

/// Claude Code adapter — the primary supported provider.
/// Supports native --remote, hooks auto-configured by AutoConfigurator.
public struct ClaudeCodeAdapter: ProviderAdapter {
    public let id = "claude-code"
    public let displayName = "Claude Code"
    public let supportsNativeRemote = true

    public init() {}

    public var isInstalled: Bool {
        which("claude") != nil
    }

    public func buildProcess(workspace: String, remote: Bool) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: workspace)

        var args = ["claude"]
        if remote { args.append("--remote") }
        process.arguments = args

        return process
    }

    public func parseOutput(_ line: String) -> ProviderEvent? {
        // Claude Code communicates via hooks (socket), not stdout parsing.
        // Remote URL appears in stdout when --remote is used.
        if line.contains("https://") && line.contains("claude.ai") {
            let parts = line.components(separatedBy: .whitespaces)
            if let url = parts.first(where: { $0.hasPrefix("https://") }) {
                return .remoteURL(url)
            }
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
