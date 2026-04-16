import SwiftUI
import AppKit

/// Button shown in the onboarding card. Opens the user's preferred terminal
/// application (no command injection) and lets them switch/remember a
/// different choice when multiple terminals are installed.
///
/// Single terminal → plain button ("Open Terminal").
/// Multiple terminals → menu-style button ("Open iTerm ▾") with a submenu
/// to pick + remember another.
/// Zero terminals → Terminal.app fallback (always available on macOS).
struct OpenTerminalButton: View {

    @State private var installed: [DetectedTerminal] = TerminalLauncher.installed()
    @State private var selected: DetectedTerminal? = TerminalLauncher.preferred()

    var body: some View {
        Group {
            if installed.count <= 1 {
                // Single (or none found, fallback to Terminal.app)
                Button(action: launchDefault) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                        Text("Open \(labelFor(selected))")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
            } else {
                // Multiple — menu with selection + open
                Menu {
                    ForEach(installed) { terminal in
                        Button(action: { launch(terminal) }) {
                            Label(terminal.name, systemImage: terminal.id == selected?.id ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                        Text("Open \(labelFor(selected))")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .fixedSize()
            }
        }
        .onAppear {
            // Refresh in case the user installed a terminal after first launch.
            installed = TerminalLauncher.installed()
            selected = TerminalLauncher.preferred()
        }
    }

    private func launchDefault() {
        if let terminal = selected {
            TerminalLauncher.launch(terminal)
            return
        }
        // Last-resort fallback: Terminal.app always exists at a known path on macOS.
        // This covers the (extremely unlikely) case where urlForApplication lookup
        // failed for every candidate bundle id.
        let terminalPath = "/System/Applications/Utilities/Terminal.app"
        NSWorkspace.shared.open(URL(fileURLWithPath: terminalPath))
    }

    private func launch(_ terminal: DetectedTerminal) {
        selected = terminal
        TerminalLauncher.setPreferred(terminal)
        TerminalLauncher.launch(terminal)
    }

    private func labelFor(_ terminal: DetectedTerminal?) -> String {
        terminal?.name ?? "Terminal"
    }
}
