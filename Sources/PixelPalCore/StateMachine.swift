import Foundation

public enum CharacterState: String {
    case idle
    case working
    case celebrate
    case nudge
    case comfort
}

public struct ShellEvent {
    public enum Kind: String, Codable { case exec, prompt, claude_notify, claude_stop }
    public let kind: Kind
    public let timestamp: TimeInterval
    public let command: String?
    public let exitCode: Int?
    public let duration: Int?
    public let pwd: String?
    public let gitBranch: String?

    public init(kind: Kind, timestamp: TimeInterval, command: String?, exitCode: Int?, duration: Int?, pwd: String?, gitBranch: String?) {
        self.kind = kind
        self.timestamp = timestamp
        self.command = command
        self.exitCode = exitCode
        self.duration = duration
        self.pwd = pwd
        self.gitBranch = gitBranch
    }
}

@MainActor
public final class StateMachine: ObservableObject {
    @Published public var state: CharacterState = .idle
    @Published public private(set) var workMinutes: Int = 0
    @Published public private(set) var gitBranch: String = ""
    @Published public var showBubble: Bool = false
    @Published public private(set) var bubbleText: String = ""
    @Published public private(set) var bubbleCharacterName: String = ""

    private var workStartTime: Date?
    private var lastBreakTime = Date()
    private var debounceTimer: Timer?
    private var workTimer: Timer?
    private var transitionTimer: Timer?
    private var dismissCount = 0
    private var dismissWindowStart: Date?
    private var silentUntil: Date?

    public init() {
        startWorkTimer()
    }

    /// WorkContext receives the same events for aggregation
    public var workContext: WorkContext?

    public func handleEvent(_ event: ShellEvent) {
        let timestamp = Date(timeIntervalSince1970: event.timestamp)

        switch event.kind {
        case .exec:
            debounceTimer?.invalidate()
            debounceTimer = nil
            state = .working
            if workStartTime == nil { workStartTime = Date() }
            workContext?.recordExec(command: event.command ?? "", timestamp: timestamp)

        case .prompt:
            let exitCode = event.exitCode ?? 0
            let duration = event.duration ?? 0
            workContext?.recordPrompt(exitCode: exitCode, duration: duration, gitBranch: event.gitBranch, timestamp: timestamp)

            if exitCode != 0 && duration > 3 {
                state = .comfort
                // Speech now handled by SpeechEngine, not raw SpeechPool
                scheduleTransition(to: .idle, after: 3.0)
            } else {
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.state = .idle }
                }
            }
            if let git = event.gitBranch, !git.isEmpty { gitBranch = git }
            if let dur = event.duration { workMinutes += dur / 60 }

        case .claude_notify:
            let previousState = state
            state = .celebrate
            scheduleTransition(to: previousState == .working ? .working : .idle, after: 3.0)

        case .claude_stop:
            state = .celebrate
            scheduleTransition(to: .idle, after: 3.0)
        }
    }

    /// Set by MenuBarController to enable character-specific speech
    public var activeCharacterId: String = "spike"

    // Break reminders moved to SpeechEngine (context-aware, not timer-based)

    public func userDismissedBubble() {
        showBubble = false
        let now = Date()
        if let start = dismissWindowStart, now.timeIntervalSince(start) < 300 {
            dismissCount += 1
            if dismissCount >= 2 {
                silentUntil = now.addingTimeInterval(3600) // silent 1 hour
                dismissCount = 0
                dismissWindowStart = nil
            }
        } else {
            dismissWindowStart = now
            dismissCount = 1
        }
    }

    public func userTookBreak() {
        lastBreakTime = Date()
        workMinutes = 0
    }

    private func showBubbleMessage(_ text: String) {
        bubbleText = text
        showBubble = true
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showBubble = false
        }
    }

    private func canShowBubble() -> Bool {
        if let silent = silentUntil, Date() < silent { return false }
        return true
    }

    private func scheduleTransition(to target: CharacterState, after seconds: TimeInterval) {
        transitionTimer?.invalidate()
        transitionTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.state = target }
        }
    }

    private func startWorkTimer() {
        // Kept for work minute tracking; speech triggers moved to SpeechEngine
        workTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // Timer kept alive to maintain scheduling; SpeechEngine polls WorkContext
        }
    }

    // MARK: - Public bubble methods (used by MenuBarController)

    public func showReminderBubble(_ text: String) {
        guard canShowBubble() else { return }
        state = .nudge
        showBubbleMessage(text)
        scheduleTransition(to: .idle, after: 8.0)
    }

    public func showDiscoveryBubble(_ greeting: String, characterName: String) {
        bubbleCharacterName = characterName
        showBubbleMessage(greeting)
    }
}
