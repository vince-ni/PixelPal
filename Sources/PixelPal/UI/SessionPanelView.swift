import SwiftUI
import PixelPalCore

/// Session panel shown when clicking the menu bar icon or floating character.
/// Lists all agent sessions with status, shows companion log, work stats.
struct SessionPanelView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var discoveryManager: DiscoveryManager
    @ObservedObject var workPatternStore: WorkPatternStore
    @ObservedObject var workContext: WorkContext
    @ObservedObject var stateMachine: StateMachine
    let onTakeBreak: () -> Void
    let onToggleMinimal: (Bool) -> Void
    let onUninstall: () -> Void
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

            // Work dashboard
            workDashboard
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

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
                Text("\(ProviderRegistry.adapter(for: session.provider)?.displayName ?? session.provider) · \(session.elapsedMinutes) min")
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
            HStack {
                Text("\(discoveryManager.discovered.count)/\(DiscoveryManager.allCharacters.count) discovered")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                #if DEBUG
                Button("Unlock All") {
                    discoveryManager.discoverAll()
                }
                .font(.system(size: 10))
                .foregroundColor(.orange)
                #endif
            }
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
                    Text("Day \(discovery?.evolutionDays ?? 0) · \(EvolutionStage.from(days: discovery?.evolutionDays ?? 0).label) · \(character.style)")
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

    @State private var showUninstallConfirm = false
    @State private var isMinimalMode = UserDefaults.standard.bool(forKey: "pixelpal_minimal_mode")

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Toggle("Minimal", isOn: $isMinimalMode)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))
                    .onChange(of: isMinimalMode) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "pixelpal_minimal_mode")
                        onToggleMinimal(newValue)
                    }
                    .help("Hide floating character, keep menu bar icon only")
                Spacer()
                Button("I took a break", action: onTakeBreak)
                    .font(.system(size: 11))
            }
            HStack {
                Button("Uninstall") { showUninstallConfirm = true }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .alert("Uninstall PixelPal?", isPresented: $showUninstallConfirm) {
                        Button("Remove hooks only") { onUninstall() }
                        Button("Cancel", role: .cancel) {}
                    }
                    message: {
                        Text("This will remove all hooks from your shell and Claude Code config. Your character data will be kept.")
                    }
                Spacer()
                Button("Quit", action: onQuit)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Work Dashboard

    private var workDashboard: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Today's summary row
            HStack(spacing: 12) {
                dashStat(icon: "clock", value: formatHours(workPatternStore.todaySummary.totalWorkMinutes), label: "today")
                dashStat(icon: "checkmark.circle", value: "\(workContext.todayCommits)", label: "commits")
                dashStat(icon: "xmark.circle", value: "\(workContext.todayErrors)", label: "errors")
                dashStat(icon: "cup.and.saucer", value: "\(workPatternStore.todaySummary.breakCount)", label: "breaks")
            }

            // Current context row
            HStack(spacing: 6) {
                if !workContext.currentBranch.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text("\(workContext.currentBranch)")
                            .font(.system(size: 10, weight: .medium))
                        Text("· \(workContext.branchMinutes)m")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if workContext.isFlowState {
                    HStack(spacing: 3) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text("flow · \(workContext.flowMinutes)m")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else if workContext.minutesSinceBreak > 0 {
                    Text("break \(workContext.minutesSinceBreak)m ago")
                        .font(.system(size: 10))
                        .foregroundColor(workContext.minutesSinceBreak > 52 ? .orange : .secondary)
                }
            }
        }
    }

    private func dashStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }

    private func formatHours(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)h\(m > 0 ? "\(m)m" : "")"
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

    private var installedProviders: [ProviderAdapter] {
        ProviderRegistry.installed
    }

    private var selectedAdapter: ProviderAdapter? {
        ProviderRegistry.adapter(for: selectedProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Session")
                .font(.headline)

            Picker("Provider", selection: $selectedProvider) {
                ForEach(installedProviders, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
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
                .disabled(selectedAdapter?.supportsNativeRemote != true)
                .help(selectedAdapter?.supportsNativeRemote == true ? "" : "This provider doesn't support native remote")

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
