import AppKit

/// A macOS terminal application detected on the current machine.
public struct DetectedTerminal: Identifiable, Equatable {
    public let id: String       // bundle identifier
    public let name: String     // "iTerm2"
    public let url: URL         // /Applications/iTerm.app
}

/// Detects installed terminal applications and opens them for the user.
///
/// Deliberately thin surface: this module does **not** inject any command
/// into the terminal it launches. PixelPal observes the user's workflow;
/// it does not drive it. If the user wants to run `claude`, they type it
/// themselves — the shell hook takes over from there.
public enum TerminalLauncher {

    /// Ordered by "developer preference" — modern / power-user terminals
    /// first, Apple Terminal.app as the universal fallback. Preserves this
    /// order when building the default menu.
    public static let candidates: [(name: String, bundleId: String)] = [
        ("Ghostty",   "com.mitchellh.ghostty"),
        ("iTerm",     "com.googlecode.iterm2"),
        ("Warp",      "dev.warp.Warp-Stable"),
        ("Kitty",     "net.kovidgoyal.kitty"),
        ("Alacritty", "io.alacritty"),
        ("WezTerm",   "com.github.wez.wezterm"),
        ("Hyper",     "co.zeit.hyper"),
        ("Terminal",  "com.apple.Terminal"),
    ]

    /// The set of terminals that respond to an `urlForApplication(bundleId:)`
    /// lookup on this machine, in preference order, de-duplicated by id.
    public static func installed(using workspace: NSWorkspace = .shared) -> [DetectedTerminal] {
        var seen = Set<String>()
        var result: [DetectedTerminal] = []
        for candidate in candidates {
            guard !seen.contains(candidate.bundleId) else { continue }
            guard let url = workspace.urlForApplication(withBundleIdentifier: candidate.bundleId) else { continue }
            seen.insert(candidate.bundleId)
            result.append(DetectedTerminal(
                id: candidate.bundleId,
                name: candidate.name,
                url: url
            ))
        }
        return result
    }

    /// The terminal the user previously picked, if it's still installed;
    /// otherwise the first detected terminal. Nil only if no terminal at all
    /// is reachable (extremely unlikely — Terminal.app ships with macOS).
    public static func preferred(
        userDefaults: UserDefaults = .standard,
        workspace: NSWorkspace = .shared
    ) -> DetectedTerminal? {
        let list = installed(using: workspace)
        if let savedId = userDefaults.string(forKey: preferredKey),
           let match = list.first(where: { $0.id == savedId }) {
            return match
        }
        return list.first
    }

    /// Persist the user's choice of terminal. Read back by `preferred(...)`.
    public static func setPreferred(_ terminal: DetectedTerminal, userDefaults: UserDefaults = .standard) {
        userDefaults.set(terminal.id, forKey: preferredKey)
    }

    /// Open the specified terminal application. No command is injected —
    /// the user opens a fresh terminal and proceeds however they like.
    public static func launch(_ terminal: DetectedTerminal, workspace: NSWorkspace = .shared) {
        workspace.open(terminal.url)
    }

    static let preferredKey = "pixelpal_preferred_terminal"
}
