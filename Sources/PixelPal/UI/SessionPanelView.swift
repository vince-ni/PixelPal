import SwiftUI

/// Session panel shown when clicking the menu bar icon or floating character.
/// Lists all agent sessions with status, shows companion log, work stats.
struct SessionPanelView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var discoveryManager: DiscoveryManager
    @ObservedObject var workPatternStore: WorkPatternStore
    @ObservedObject var stateMachine: StateMachine
    let onTakeBreak: () -> Void
    let onQuit: () -> Void

    @State private var showNewSession = false
    @State private var selectedTab = 0  // 0=sessions, 1=companions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
            Divider()

            // Tab bar
            Picker("", selection: $selectedTab) {
                Text("Sessions").tag(0)
                Text("Companions").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                sessionsTab
            } else {
                companionsTab
            }

            Divider()
            footer
        }
        .frame(width: 280)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("PixelPal")
                .font(.headline)
            Spacer()
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            Text(stateMachine.state.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Sessions Tab

    private var sessionsTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 8) {
                    Text("No active sessions")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Work in any terminal — PixelPal tracks your shell activity automatically.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
            } else {
                ForEach(sessionManager.sessions) { session in
                    sessionRow(session)
                }
                .padding(.horizontal, 12)
            }

            // Work stats
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                Text("Today: \(workPatternStore.todaySummary.totalWorkMinutes) min, \(workPatternStore.todaySummary.breakCount) breaks")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !stateMachine.gitBranch.isEmpty {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text(stateMachine.gitBranch)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            // New session button
            Button(action: { showNewSession = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Session")
                }
                .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .popover(isPresented: $showNewSession) {
                NewSessionView(sessionManager: sessionManager, isPresented: $showNewSession)
            }
        }
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(session.status))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .font(.system(size: 12, weight: .medium))
                Text("\(session.provider) · \(session.elapsedMinutes) min")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if session.isRemote {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
            }

            Button(action: { sessionManager.stopSession(session.id) }) {
                Image(systemName: "stop.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Companions Tab (Companion Log)

    private var companionsTab: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(discoveryManager.discovered.count)/\(DiscoveryManager.allCharacters.count) discovered")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 4)

            ForEach(DiscoveryManager.allCharacters, id: \.id) { character in
                companionRow(character)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func companionRow(_ character: CharacterProfile) -> some View {
        let isFound = discoveryManager.isDiscovered(character.id)
        let discovery = discoveryManager.discovered.first(where: { $0.characterId == character.id })

        return HStack(spacing: 8) {
            if isFound {
                Text(emojiFor(character.species))
                    .font(.system(size: 16))
            } else {
                Text("▓▓")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 1) {
                if isFound {
                    Text(character.name)
                        .font(.system(size: 12, weight: .medium))
                    Text("Day \(discovery?.evolutionDays ?? 0) · \(character.style)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("????????")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(character.hint)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                        .italic()
                }
            }

            Spacer()

            if isFound && discovery?.isActive == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            } else if isFound {
                Button(action: { discoveryManager.setActive(character.id) }) {
                    Text("Use")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("I took a break", action: onTakeBreak)
                .font(.system(size: 11))
            Spacer()
            Button("Quit", action: onQuit)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch stateMachine.state {
        case .idle: return .green
        case .working: return .blue
        case .celebrate: return .yellow
        case .nudge: return .orange
        case .comfort: return .purple
        }
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .running: return .green
        case .idle: return .gray
        case .error: return .red
        case .stopped: return .gray.opacity(0.5)
        }
    }

    private func emojiFor(_ species: String) -> String {
        switch species {
        case "Hedgehog": return "🦔"
        case "Cheetah": return "🐆"
        case "Golden Retriever": return "🐕"
        case "Owl": return "🦉"
        case "Turtle": return "🐢"
        case "Fox": return "🦊"
        case "Phoenix": return "🔥"
        case "Dragon": return "🐉"
        case "Slime": return "🫧"
        default: return "❓"
        }
    }
}

// MARK: - New Session View

struct NewSessionView: View {
    @ObservedObject var sessionManager: SessionManager
    @Binding var isPresented: Bool

    @State private var selectedProvider = "claude-code"
    @State private var workspace = ""
    @State private var enableRemote = false

    let providers = ["claude-code", "codex", "aider"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Session")
                .font(.headline)

            Picker("Provider", selection: $selectedProvider) {
                ForEach(providers, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)

            HStack {
                Text("Directory")
                    .font(.system(size: 12))
                TextField("~/Projects/...", text: $workspace)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            Toggle("Enable Remote", isOn: $enableRemote)
                .font(.system(size: 12))

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Start") {
                    let dir = workspace.isEmpty
                        ? FileManager.default.homeDirectoryForCurrentUser.path
                        : (workspace as NSString).expandingTildeInPath
                    sessionManager.createSession(provider: selectedProvider, workspace: dir, remote: enableRemote)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
