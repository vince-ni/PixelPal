import Foundation

/// Three-layer scientific break reminder engine.
/// Layer 1: Eye rest — 20 min (20-20-20 rule)
/// Layer 2: Micro break — 52 min (Pomodoro-adjacent)
/// Layer 3: Deep rest — 90 min (ultradian rhythm)
///
/// Gradual unlock: Day 1 only Layer 1, Day 3 adds Layer 2, Day 7 adds Layer 3.
/// Reminders are NOT tied to growth, currency, or any reward system.
@MainActor
final class ReminderEngine: ObservableObject {
    @Published private(set) var currentReminder: Reminder?

    struct Reminder {
        let layer: Int               // 1, 2, or 3
        let message: String
        let emoji: String
    }

    private var lastBreakTime = Date()
    private var checkTimer: Timer?
    private var silentUntil: Date?
    private var dismissCount = 0
    private var dismissWindowStart: Date?
    private let installDate: Date

    init(installDate: Date = Date()) {
        self.installDate = installDate
        startChecking()
    }

    // MARK: - Configuration

    private var daysSinceInstall: Int {
        max(0, Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0)
    }

    private var enabledLayers: Set<Int> {
        var layers: Set<Int> = [1]           // Layer 1 always enabled
        if daysSinceInstall >= 3 { layers.insert(2) }  // Day 3+
        if daysSinceInstall >= 7 { layers.insert(3) }  // Day 7+
        return layers
    }

    // MARK: - Check cycle

    private func startChecking() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
    }

    func evaluate() {
        guard canShowReminder() else { return }

        let minutesSinceBreak = Int(Date().timeIntervalSince(lastBreakTime) / 60)
        let layers = enabledLayers

        // Check from deepest to shallowest (most urgent first)
        if layers.contains(3) && minutesSinceBreak >= 90 {
            showReminder(Reminder(
                layer: 3,
                message: "\(minutesSinceBreak) minutes straight. Stand up, walk around.",
                emoji: "🚶"
            ))
        } else if layers.contains(2) && minutesSinceBreak >= 52 {
            showReminder(Reminder(
                layer: 2,
                message: "Good stretch point. Step away for a few minutes.",
                emoji: "☕"
            ))
        } else if layers.contains(1) && minutesSinceBreak >= 20 {
            showReminder(Reminder(
                layer: 1,
                message: "Look at something 20 feet away for 20 seconds.",
                emoji: "👀"
            ))
        }
    }

    // MARK: - User actions

    func userTookBreak() {
        lastBreakTime = Date()
        currentReminder = nil
    }

    func userDismissedReminder() {
        currentReminder = nil
        trackDismissal()
    }

    /// Called when shell goes idle for >5 min (implicit break)
    func idleDetected() {
        lastBreakTime = Date()
    }

    // MARK: - Overload protection

    /// 2 dismissals in 5 minutes → silent 1 hour
    private func trackDismissal() {
        let now = Date()
        if let start = dismissWindowStart, now.timeIntervalSince(start) < 300 {
            dismissCount += 1
            if dismissCount >= 2 {
                silentUntil = now.addingTimeInterval(3600)
                dismissCount = 0
                dismissWindowStart = nil
                print("[PixelPal] Overload protection: silent for 1 hour")
            }
        } else {
            dismissWindowStart = now
            dismissCount = 1
        }
    }

    private func canShowReminder() -> Bool {
        if currentReminder != nil { return false }  // already showing one
        if let silent = silentUntil, Date() < silent { return false }
        return true
    }

    private func showReminder(_ reminder: Reminder) {
        currentReminder = reminder
        // Auto-dismiss after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.currentReminder?.layer == reminder.layer {
                self?.currentReminder = nil
            }
        }
    }

    // MARK: - Stats for discovery conditions

    var breaksTaken: Int {
        // This is a simplified count. In production, persist to WorkPatternStore.
        _breaksTakenCount
    }
    private var _breaksTakenCount = 0

    func recordBreak() {
        _breaksTakenCount += 1
        userTookBreak()
    }
}
