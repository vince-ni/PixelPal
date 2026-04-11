import Foundation

enum CharacterState: String {
    case idle
    case working
    case celebrate
    case nudge
    case comfort
}

struct ShellEvent {
    enum Kind: String, Codable { case exec, prompt, claude_notify, claude_stop }
    let kind: Kind
    let timestamp: TimeInterval
    let command: String?
    let exitCode: Int?
    let duration: Int?
    let pwd: String?
    let gitBranch: String?
}

@MainActor
final class StateMachine: ObservableObject {
    @Published var state: CharacterState = .idle
    @Published private(set) var workMinutes: Int = 0
    @Published private(set) var gitBranch: String = ""
    @Published var showBubble: Bool = false
    @Published private(set) var bubbleText: String = ""
    @Published private(set) var bubbleCharacterName: String = ""

    private var workStartTime: Date?
    private var lastBreakTime = Date()
    private var debounceTimer: Timer?
    private var workTimer: Timer?
    private var transitionTimer: Timer?
    private var dismissCount = 0
    private var dismissWindowStart: Date?
    private var silentUntil: Date?

    init() {
        startWorkTimer()
    }

    func handleEvent(_ event: ShellEvent) {
        switch event.kind {
        case .exec:
            debounceTimer?.invalidate()
            debounceTimer = nil
            state = .working
            if workStartTime == nil { workStartTime = Date() }

        case .prompt:
            if let exit = event.exitCode, exit != 0, let dur = event.duration, dur > 3 {
                state = .comfort
                scheduleTransition(to: .idle, after: 3.0)
            } else {
                // 2-second debounce: don't go idle immediately
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.state = .idle }
                }
            }
            if let git = event.gitBranch, !git.isEmpty { gitBranch = git }
            if let dur = event.duration { workMinutes += dur / 60 }

            // Idle detection: if gap between prompts > 5 min, pause work timer
            // (handled by workTimer checking last event time)
            checkBreakReminders()

        case .claude_notify:
            state = .celebrate
            scheduleTransition(to: state == .working ? .working : .idle, after: 3.0)
            showBubbleMessage("Claude needs you!")

        case .claude_stop:
            state = .celebrate
            scheduleTransition(to: .idle, after: 3.0)
        }
    }

    private func checkBreakReminders() {
        guard canShowBubble() else { return }
        let minutesSinceBreak = Int(Date().timeIntervalSince(lastBreakTime) / 60)

        if minutesSinceBreak >= 25 {
            state = .nudge
            showBubbleMessage(minutesSinceBreak >= 52
                ? "Already \(minutesSinceBreak) min. Take a real break."
                : "25 min in. Look away for 20 sec.")
            scheduleTransition(to: .idle, after: 5.0)
        }
    }

    func userDismissedBubble() {
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

    func userTookBreak() {
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
        workTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.state == .working || self.state == .idle {
                    self.checkBreakReminders()
                }
            }
        }
    }

    // MARK: - Public bubble methods (used by MenuBarController)

    func showReminderBubble(_ text: String) {
        guard canShowBubble() else { return }
        state = .nudge
        showBubbleMessage(text)
        scheduleTransition(to: .idle, after: 8.0)
    }

    func showDiscoveryBubble(_ greeting: String, characterName: String) {
        bubbleCharacterName = characterName
        showBubbleMessage(greeting)
    }
}
