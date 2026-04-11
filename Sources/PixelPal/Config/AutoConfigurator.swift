import Foundation

/// Zero-config installer: auto-detects installed AI tools and injects hooks on first launch.
/// Follows the 10-rule safety checklist from PRD.
final class AutoConfigurator {

    struct ConfigResult {
        var claudeCode: Bool = false
        var shellHook: Bool = false
        var errors: [String] = []
    }

    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    private let socketPath: String

    init() {
        let tmpDir = ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"
        socketPath = (tmpDir as NSString).appendingPathComponent("pixelpal.sock")
    }

    /// Run all auto-configuration. Safe to call multiple times (idempotent).
    func configure() -> ConfigResult {
        var result = ConfigResult()

        // Claude Code hooks
        if detectClaudeCode() {
            switch injectClaudeHooks() {
            case .success:
                result.claudeCode = true
                print("[PixelPal] Claude Code hooks configured")
            case .alreadyConfigured:
                result.claudeCode = true
                print("[PixelPal] Claude Code hooks already present")
            case .error(let msg):
                result.errors.append("Claude Code: \(msg)")
                print("[PixelPal] Claude Code hook injection failed: \(msg)")
            }
        }

        // Shell hook (.zshrc)
        switch injectShellHook() {
        case .success:
            result.shellHook = true
            print("[PixelPal] Shell hook configured in .zshrc")
        case .alreadyConfigured:
            result.shellHook = true
            print("[PixelPal] Shell hook already present in .zshrc")
        case .error(let msg):
            result.errors.append("Shell: \(msg)")
            print("[PixelPal] Shell hook injection failed: \(msg)")
        }

        return result
    }

    /// Remove all injected hooks (called on uninstall).
    func unconfigure() {
        removeClaudeHooks()
        removeShellHook()
        print("[PixelPal] All hooks removed")
    }

    // MARK: - Detection

    private func detectClaudeCode() -> Bool {
        let configPath = (homeDir as NSString).appendingPathComponent(".claude/settings.json")
        return FileManager.default.fileExists(atPath: configPath)
    }

    // MARK: - Claude Code Hook Injection (10-rule safety checklist)

    private enum InjectionResult {
        case success
        case alreadyConfigured
        case error(String)
    }

    private func injectClaudeHooks() -> InjectionResult {
        let configPath = (homeDir as NSString).appendingPathComponent(".claude/settings.json")

        // Rule 3: Read existing config
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            return .error("Cannot read settings.json")
        }

        guard var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .error("Cannot parse settings.json — not modifying")
        }

        // Rule 3: Check if already configured (idempotent)
        if let hooks = config["hooks"] as? [String: Any] {
            if let notifHooks = hooks["Notification"] as? [[String: Any]] {
                for hook in notifHooks {
                    if let innerHooks = hook["hooks"] as? [[String: Any]] {
                        for h in innerHooks {
                            if let cmd = h["command"] as? String, cmd.contains("pixelpal") {
                                return .alreadyConfigured
                            }
                        }
                    }
                }
            }
        }

        // Rule 3: Backup before modification
        let backupPath = configPath + ".pre-pixelpal"
        if !FileManager.default.fileExists(atPath: backupPath) {
            try? FileManager.default.copyItem(atPath: configPath, toPath: backupPath)
        }

        // Rule 2: Inline commands, no external scripts. nc -w0, exit 0, 2>/dev/null
        let notifyCmd = "echo '{\"e\":\"claude_notify\",\"t\":'$(date +%s)'}' | nc -w0 -U \(socketPath) 2>/dev/null; exit 0"
        // Rule 4: Don't use Stop hook (known bug claude-code #26770). Use PostToolUse instead.
        let postToolCmd = "echo '{\"e\":\"claude_stop\",\"t\":'$(date +%s)'}' | nc -w0 -U \(socketPath) 2>/dev/null; exit 0"

        let pixelpalNotifHook: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": notifyCmd]
            ]
        ]

        let pixelpalPostToolHook: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": postToolCmd]
            ]
        ]

        // Rule 3: Append to existing arrays, never replace
        var hooks = config["hooks"] as? [String: Any] ?? [:]

        var notifArray = hooks["Notification"] as? [[String: Any]] ?? []
        notifArray.append(pixelpalNotifHook)
        hooks["Notification"] = notifArray

        var postToolArray = hooks["PostToolUse"] as? [[String: Any]] ?? []
        postToolArray.append(pixelpalPostToolHook)
        hooks["PostToolUse"] = postToolArray

        config["hooks"] = hooks

        // Rule 3: Write back
        guard let newData = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) else {
            return .error("Cannot serialize updated config")
        }

        // Rule 3: Validate after write
        do {
            try newData.write(to: URL(fileURLWithPath: configPath))
            // Verify the written file is valid JSON
            let verifyData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            _ = try JSONSerialization.jsonObject(with: verifyData)
            return .success
        } catch {
            // Restore backup on failure
            try? FileManager.default.removeItem(atPath: configPath)
            try? FileManager.default.copyItem(atPath: backupPath, toPath: configPath)
            return .error("Write failed, restored backup: \(error.localizedDescription)")
        }
    }

    private func removeClaudeHooks() {
        let configPath = (homeDir as NSString).appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = config["hooks"] as? [String: Any] else { return }

        // Remove PixelPal entries from Notification and PostToolUse arrays
        for key in ["Notification", "PostToolUse"] {
            if var arr = hooks[key] as? [[String: Any]] {
                arr.removeAll { hook in
                    guard let innerHooks = hook["hooks"] as? [[String: Any]] else { return false }
                    return innerHooks.contains { h in
                        (h["command"] as? String)?.contains("pixelpal") ?? false
                    }
                }
                hooks[key] = arr.isEmpty ? nil : arr
            }
        }

        config["hooks"] = hooks
        if let newData = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) {
            try? newData.write(to: URL(fileURLWithPath: configPath))
        }
    }

    // MARK: - Shell Hook Injection

    private func injectShellHook() -> InjectionResult {
        let zshrcPath = (homeDir as NSString).appendingPathComponent(".zshrc")

        guard var content = try? String(contentsOfFile: zshrcPath, encoding: .utf8) else {
            return .error("Cannot read .zshrc")
        }

        // Check if already present
        if content.contains("pixelpal.zsh") {
            return .alreadyConfigured
        }

        // Find the shell hook path
        let hookPaths = [
            Bundle.main.resourcePath.map { ($0 as NSString).appendingPathComponent("pixelpal.zsh") },
            (homeDir as NSString).appendingPathComponent("Projects/PixelPal/Shell/pixelpal.zsh")
        ].compactMap { $0 }

        guard let hookPath = hookPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return .error("pixelpal.zsh not found")
        }

        let injection = """

        # PixelPal shell integration (auto-configured, safe to remove)
        [[ -f "\(hookPath)" ]] && source "\(hookPath)"
        """

        content += injection

        do {
            try content.write(toFile: zshrcPath, atomically: true, encoding: .utf8)
            return .success
        } catch {
            return .error("Cannot write .zshrc: \(error.localizedDescription)")
        }
    }

    private func removeShellHook() {
        let zshrcPath = (homeDir as NSString).appendingPathComponent(".zshrc")
        guard var content = try? String(contentsOfFile: zshrcPath, encoding: .utf8) else { return }

        // Remove PixelPal block
        let lines = content.components(separatedBy: "\n")
        var filtered: [String] = []
        var skipping = false
        for line in lines {
            if line.contains("# PixelPal shell integration") {
                skipping = true
                continue
            }
            if skipping && line.contains("pixelpal.zsh") {
                skipping = false
                continue
            }
            skipping = false
            filtered.append(line)
        }
        content = filtered.joined(separator: "\n")
        try? content.write(toFile: zshrcPath, atomically: true, encoding: .utf8)
    }
}
