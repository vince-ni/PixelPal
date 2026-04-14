import SwiftUI
import PixelPalCore

/// Parse a `#RRGGBB` / `RRGGBB` hex string into a SwiftUI `Color`.
/// Returns nil for malformed input so the caller can fall back to system accent.
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

/// Session panel shown when clicking the menu bar icon or floating character.
/// Lists all agent sessions with status, shows companion log, work stats.
struct SessionPanelView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var discoveryManager: DiscoveryManager
    @ObservedObject var workPatternStore: WorkPatternStore
    @ObservedObject var workContext: WorkContext
    @ObservedObject var stateMachine: StateMachine
    let onToggleMinimal: (Bool) -> Void
    let onUninstall: () -> Void
    let onQuit: () -> Void
    let onReconfigureNtfy: () -> Void

    @State private var showNewSession = false
    @State private var selectedTab = 0  // 0=sessions, 1=companions

    private var activeAccent: Color {
        Color(hex: discoveryManager.activeCharacter.accentHex) ?? .accentColor
    }

    var body: some View {
        panelBody
            .tint(activeAccent)
    }

    private var panelBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (character-first)
            header
            Divider()

            // Global work dashboard — visible in every tab.
            // Light card treatment makes it read as a status region, not
            // just another row wedged between two dividers.
            workDashboard
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.06))
                )
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)

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
            ambientFooter
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    // MARK: - Ambient footer (character-in-the-room)

    /// A quiet one-line signature of presence at the bottom of the panel.
    /// Carries the most recent speech bubble text (so a bubble fading from
    /// the corner lingers here as a record) or a relationship anchor when
    /// the character hasn't said anything yet today.
    private var ambientLine: String {
        let text = stateMachine.bubbleText
        if !text.isEmpty { return text }
        if activeEvolutionDays > 0 { return "\(activeEvolutionDays) days together so far." }
        return "Here for you."
    }

    private var ambientFooter: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\u{201C}\(ambientLine)\u{201D}")
                .font(.system(size: 11, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Text("— \(discoveryManager.activeCharacter.name)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Header (character-first)

    private var activeEvolutionDays: Int {
        discoveryManager.discovered.first(where: { $0.isActive })?.evolutionDays ?? 0
    }

    private var activeStage: EvolutionStage {
        EvolutionStage.from(days: activeEvolutionDays)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AnimatedAvatarView(
                characterId: discoveryManager.activeCharacter.id,
                state: stateMachine.state,
                evolution: activeStage,
                size: 32
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(discoveryManager.activeCharacter.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            settingsMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var headerSubtitle: String {
        let dayFragment = activeEvolutionDays > 0 ? " · Day \(activeEvolutionDays)" : ""
        let characterId = discoveryManager.activeCharacter.id
        // Idle → show the relationship (stage, character-voiced).
        // Non-idle → show the moment (state, character-voiced).
        // The day count stays as continuity anchor.
        if stateMachine.state == .idle {
            return SpeechPool.stageLabel(character: characterId, stage: activeStage) + dayFragment
        }
        return SpeechPool.stateLabel(character: characterId, state: stateMachine.state.rawValue) + dayFragment
    }

    // MARK: - Settings menu (gear)

    private var settingsMenu: some View {
        Menu {
            Button(action: { showPhoneSettings = true }) {
                Label(
                    ntfyEnabled ? "Phone notifications — on" : "Phone notifications…",
                    systemImage: ntfyEnabled ? "iphone.radiowaves.left.and.right" : "iphone"
                )
            }
            Toggle(isOn: $isMinimalMode) {
                Label("Minimal mode", systemImage: "rectangle.topthird.inset.filled")
            }
            .onChange(of: isMinimalMode) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "pixelpal_minimal_mode")
                onToggleMinimal(newValue)
            }

            Divider()

            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Label("Uninstall hooks…", systemImage: "trash")
            }
            Button(action: onQuit) {
                Label("Quit PixelPal", systemImage: "power")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 22, height: 22)
        .alert("Uninstall PixelPal?", isPresented: $showUninstallConfirm) {
            Button("Remove hooks only", role: .destructive) { onUninstall() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all hooks from your shell and Claude Code config. Your character data is kept.")
        }
        .sheet(isPresented: $showPhoneSettings) { phoneSettingsSheet }
    }

    // MARK: - Sessions Tab

    private var sessionsTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            // New session button — highest-frequency action, top placement
            Button(action: { showNewSession = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Session")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .popover(isPresented: $showNewSession) {
                NewSessionView(sessionManager: sessionManager, isPresented: $showNewSession)
            }

            if sessionManager.sessions.isEmpty {
                VStack(spacing: 6) {
                    Text("No active sessions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Work in any terminal — PixelPal tracks your shell activity automatically.")
                        .font(.system(size: 10))
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
                .padding(.bottom, 8)
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
        let isActive = discoveryManager.discovered.first(where: { $0.characterId == character.id })?.isActive == true
        let discovery = discoveryManager.discovered.first(where: { $0.characterId == character.id })

        return HStack(spacing: 10) {
            companionSprite(character: character, isFound: isFound, isActive: isActive)

            VStack(alignment: .leading, spacing: 1) {
                if isFound {
                    let days = discovery?.evolutionDays ?? 0
                    let stage = EvolutionStage.from(days: days)
                    Text(character.name)
                        .font(.system(size: 12, weight: .medium))
                    Text("Day \(days) · \(SpeechPool.stageLabel(character: character.id, stage: stage))")
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
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .onTapGesture {
            // Tap-to-activate: only discovered, not-already-active characters.
            if isFound && !isActive {
                discoveryManager.setActive(character.id)
            }
        }
    }

    /// Character sprite cell for the companion row.
    /// - Discovered + active: full color sprite inside an accent glow ring.
    /// - Discovered + inactive: full color sprite, no ring (tap to activate).
    /// - Undiscovered: black silhouette of the sprite shape — hint of identity.
    @ViewBuilder
    private func companionSprite(character: CharacterProfile, isFound: Bool, isActive: Bool) -> some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                    .frame(width: 32, height: 32)
                    .shadow(color: .accentColor.opacity(0.5), radius: 4)
            }
            if isFound {
                if let sprite = SpriteSheet.avatar(character: character.id, size: 26) {
                    Image(nsImage: sprite).interpolation(.none)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            } else {
                if let shadow = SpriteSheet.silhouette(character: character.id, size: 26) {
                    Image(nsImage: shadow).interpolation(.none)
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.35))
                }
            }
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Settings state

    @State private var showUninstallConfirm = false
    @State private var isMinimalMode = UserDefaults.standard.bool(forKey: "pixelpal_minimal_mode")
    @State private var showPhoneSettings = false
    @State private var ntfyEnabled = UserDefaults.standard.bool(forKey: "pixelpal_ntfy_enabled")
    @State private var ntfyTopic = UserDefaults.standard.string(forKey: "pixelpal_ntfy_topic") ?? ""
    @State private var ntfyTestStatus: String = ""

    // MARK: - Phone Settings Sheet

    private var phoneSettingsSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: ntfyEnabled ? "iphone.radiowaves.left.and.right" : "iphone")
                    .font(.system(size: 18))
                    .foregroundColor(ntfyEnabled ? .accentColor : .secondary)
                Text("Phone notifications")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done") { showPhoneSettings = false }
                    .keyboardShortcut(.cancelAction)
            }

            Toggle("Push to phone via ntfy", isOn: $ntfyEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .onChange(of: ntfyEnabled) { _, newValue in
                    if newValue && ntfyTopic.isEmpty {
                        ntfyTopic = NtfyRemoteSink.generateTopic()
                        UserDefaults.standard.set(ntfyTopic, forKey: "pixelpal_ntfy_topic")
                    }
                    UserDefaults.standard.set(newValue, forKey: "pixelpal_ntfy_enabled")
                    onReconfigureNtfy()
                }

            if ntfyEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topic — keep secret, anyone with this can subscribe")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Text(ntfyTopic)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(5)
                        Button(action: copyTopicToPasteboard) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy topic")
                        Button(action: regenerateTopic) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Regenerate (old topic stops working)")
                    }

                    HStack {
                        Button("Send test push") {
                            Task { await sendTestPush() }
                        }
                        Spacer()
                        if !ntfyTestStatus.isEmpty {
                            Text(ntfyTestStatus)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Install the ntfy app on your phone and subscribe to this topic.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(.regularMaterial)
                .cornerRadius(8)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 320, height: ntfyEnabled ? 280 : 160)
    }

    private func copyTopicToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ntfyTopic, forType: .string)
        ntfyTestStatus = "Copied"
    }

    private func regenerateTopic() {
        ntfyTopic = NtfyRemoteSink.generateTopic()
        UserDefaults.standard.set(ntfyTopic, forKey: "pixelpal_ntfy_topic")
        onReconfigureNtfy()
        ntfyTestStatus = "Regenerated"
    }

    private func sendTestPush() async {
        let server = UserDefaults.standard.string(forKey: "pixelpal_ntfy_server") ?? "https://ntfy.sh"
        let sink = NtfyRemoteSink(topic: ntfyTopic, server: server)
        let charName = discoveryManager.activeCharacter.name
        let test = RemoteNotification(
            kind: .taskComplete,
            characterId: discoveryManager.activeCharacter.id,
            characterName: charName,
            text: "Test from \(charName) — if you see this on your phone, you're wired up."
        )
        ntfyTestStatus = "Sending…"
        await sink.deliver(test)
        ntfyTestStatus = "Sent"
    }

    // MARK: - Work Dashboard (global, between header and tabs)

    /// Today's summary as a single information-dense line. Replaces four
    /// separate icon-stat blocks. Reads left-to-right as a sentence so the
    /// eye doesn't hop between visual cells.
    private var todaySummaryLine: String {
        let summary = workPatternStore.todaySummary
        var parts: [String] = []
        parts.append(formatHours(summary.totalWorkMinutes))
        if workContext.todayCommits > 0 { parts.append("\(workContext.todayCommits) commit\(workContext.todayCommits == 1 ? "" : "s")") }
        if workContext.todayErrors > 0 { parts.append("\(workContext.todayErrors) error\(workContext.todayErrors == 1 ? "" : "s")") }
        if summary.breakCount > 0 { parts.append("\(summary.breakCount) break\(summary.breakCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private var workDashboard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("Today")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(todaySummaryLine)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                Spacer()
            }

            // Context line: branch, flow, break. Only render when we have
            // something to say — keeps the dashboard at 1 line when empty.
            if !workContext.currentBranch.isEmpty || workContext.isFlowState || workContext.minutesSinceBreak > 0 {
                HStack(spacing: 6) {
                    if !workContext.currentBranch.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(workContext.currentBranch)
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

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .running: return .green
        case .idle: return .gray
        case .error: return .red
        case .stopped: return .gray.opacity(0.5)
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
