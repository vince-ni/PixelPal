import Foundation

/// Aider adapter — AI pair programming tool.
/// Uses --map-whole-repo for context, no native remote.
public struct AiderAdapter: ProviderAdapter {
    public let id = "aider"
    public let displayName = "Aider"
    public let supportsNativeRemote = false

    public init() {}

    public var isInstalled: Bool {
        which("aider") != nil
    }

    public func parseOutput(_ line: String) -> ProviderEvent? {
        // Aider outputs commit messages when it makes changes
        if line.hasPrefix("Commit ") && line.contains("→") {
            return .taskCompleted(exitCode: 0)
        }
        if line.contains("Applied edit to") {
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
