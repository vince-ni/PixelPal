import Foundation

/// Manages gradual unlock of reminder layers and break recording.
/// Speech decisions are handled by SpeechEngine — this module only
/// tracks policy (which layers are enabled) and break statistics.
///
/// Gradual unlock: Day 1 only eye rest, Day 3 adds micro, Day 7 adds deep.
/// Reminders are NOT tied to growth, currency, or any reward system.
@MainActor
public final class ReminderEngine: ObservableObject {

    private let installDate: Date
    private var _breaksTakenCount = 0

    public init(installDate: Date? = nil) {
        // Use stored install date or default to now
        if let stored = UserDefaults.standard.object(forKey: "pixelpal_install_date") as? Date {
            self.installDate = installDate ?? stored
        } else {
            let date = installDate ?? Date()
            self.installDate = date
            UserDefaults.standard.set(date, forKey: "pixelpal_install_date")
        }
    }

    // MARK: - Gradual unlock policy

    public var daysSinceInstall: Int {
        max(0, Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0)
    }

    /// Whether eye rest reminders (20 min) are enabled
    public var eyeRestEnabled: Bool { true } // Always enabled from Day 1

    /// Whether micro break reminders (52 min) are enabled
    public var microBreakEnabled: Bool { daysSinceInstall >= 3 }

    /// Whether deep rest reminders (90 min) are enabled
    public var deepRestEnabled: Bool { daysSinceInstall >= 7 }

    // MARK: - Break recording

    public func recordBreak() {
        _breaksTakenCount += 1
    }

    public var breaksTaken: Int { _breaksTakenCount }
}
