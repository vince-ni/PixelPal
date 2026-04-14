import Foundation

/// Real-time snapshot of the user's work state.
/// Aggregated from shell events, StateMachine, and WorkPatternStore.
/// This is the single source of truth for all speech decisions.
@MainActor
public final class WorkContext: ObservableObject {

    // MARK: - Current session state

    @Published public private(set) var currentBranch: String = ""
    @Published public private(set) var branchStartTime: Date = Date()
    @Published public private(set) var consecutiveErrors: Int = 0
    @Published public private(set) var isFlowState: Bool = false
    @Published public private(set) var flowStartTime: Date?
    @Published public private(set) var sessionStartTime: Date = Date()
    @Published public private(set) var lastActivityTime: Date = Date()
    @Published public private(set) var lastBreakTime: Date = Date()
    @Published public private(set) var todayCommits: Int = 0
    @Published public private(set) var todayErrors: Int = 0

    // MARK: - Command velocity tracking (rolling 5-min window)

    private var recentCommands: [Date] = []
    private let velocityWindow: TimeInterval = 300 // 5 minutes
    private let flowThreshold: Double = 2.0 // commands/minute to enter flow
    private let flowExitThreshold: Double = 0.5 // commands/minute to exit flow
    private let flowMinDuration: TimeInterval = 300 // 5 minutes sustained before declaring flow

    private var sustainedHighVelocityStart: Date?

    public init() {}

    /// Commands per minute in the rolling window
    public var commandVelocity: Double {
        pruneOldCommands()
        guard !recentCommands.isEmpty else { return 0 }
        let windowStart = Date().addingTimeInterval(-velocityWindow)
        let inWindow = recentCommands.filter { $0 > windowStart }
        return Double(inWindow.count) / (velocityWindow / 60.0)
    }

    /// Minutes since last break
    public var minutesSinceBreak: Int {
        Int(Date().timeIntervalSince(lastBreakTime) / 60)
    }

    /// Minutes on current branch
    public var branchMinutes: Int {
        Int(Date().timeIntervalSince(branchStartTime) / 60)
    }

    /// Minutes in current continuous session
    public var sessionMinutes: Int {
        Int(Date().timeIntervalSince(sessionStartTime) / 60)
    }

    /// Minutes since last activity (for detecting away)
    public var idleMinutes: Int {
        Int(Date().timeIntervalSince(lastActivityTime) / 60)
    }

    /// Minutes in current flow state (0 if not in flow)
    public var flowMinutes: Int {
        guard let start = flowStartTime, isFlowState else { return 0 }
        return Int(Date().timeIntervalSince(start) / 60)
    }

    // MARK: - Event ingestion

    /// Called on every shell exec event
    public func recordExec(command: String, timestamp: Date) {
        lastActivityTime = timestamp
        recentCommands.append(timestamp)

        // Reset idle session if returning after long absence
        if idleMinutes > 5 {
            sessionStartTime = timestamp
        }

        updateFlowState()
    }

    /// Called on every shell prompt event (command completed)
    public func recordPrompt(exitCode: Int, duration: Int, gitBranch: String?, timestamp: Date) {
        lastActivityTime = timestamp

        // Track errors
        if exitCode != 0 && duration > 1 {
            consecutiveErrors += 1
            todayErrors += 1
        } else if exitCode == 0 {
            consecutiveErrors = 0
            if duration > 1 {
                todayCommits += 1
            }
        }

        // Track branch changes
        if let branch = gitBranch, !branch.isEmpty, branch != currentBranch {
            let oldBranch = currentBranch
            let oldDuration = branchMinutes
            currentBranch = branch
            branchStartTime = timestamp
            // Store for speech engine to reference
            if !oldBranch.isEmpty && oldDuration > 10 {
                lastBranchSwitch = (from: oldBranch, duration: oldDuration)
            }
        }

        updateFlowState()
    }

    /// Called when user takes a break
    public func recordBreak() {
        lastBreakTime = Date()
    }

    /// Called when user returns after absence (> 5 min idle)
    public var returningFromAbsence: Bool {
        idleMinutes > 5
    }

    /// Last branch switch info (for speech context)
    public var lastBranchSwitch: (from: String, duration: Int)?

    // MARK: - Flow state machine

    private func updateFlowState() {
        let velocity = commandVelocity
        let now = Date()

        if !isFlowState {
            // Check for flow entry
            if velocity >= flowThreshold {
                if sustainedHighVelocityStart == nil {
                    sustainedHighVelocityStart = now
                } else if now.timeIntervalSince(sustainedHighVelocityStart!) >= flowMinDuration {
                    isFlowState = true
                    flowStartTime = sustainedHighVelocityStart
                }
            } else {
                sustainedHighVelocityStart = nil
            }
        } else {
            // Check for flow exit
            if velocity < flowExitThreshold {
                isFlowState = false
                flowStartTime = nil
                sustainedHighVelocityStart = nil
            }
        }
    }

    private func pruneOldCommands() {
        let cutoff = Date().addingTimeInterval(-velocityWindow)
        recentCommands.removeAll { $0 < cutoff }
    }

    // MARK: - Daily reset

    private var lastResetDate: String = ""

    public func resetIfNewDay() {
        let today = WorkPatternStore.dateString(Date())
        if today != lastResetDate {
            todayCommits = 0
            todayErrors = 0
            lastResetDate = today
        }
    }
}
