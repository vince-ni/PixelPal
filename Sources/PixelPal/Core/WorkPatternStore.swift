import Foundation

/// Persists work pattern data locally. This data powers:
/// 1. Weekly report card (Phase 1)
/// 2. Discovery condition evaluation
/// 3. B2B team health dashboard (Phase 3, aggregated + anonymized)
///
/// Privacy: all data stays local. No command content, no file paths, no code.
/// Only timing and outcome metadata.
@MainActor
final class WorkPatternStore: ObservableObject {
    @Published private(set) var todaySummary: DailySummary
    @Published private(set) var workStats: WorkStats

    private var eventLog: [WorkEvent] = []
    private let dataDir: URL
    private let statsPath: String

    struct WorkEvent: Codable {
        let timestamp: Date
        let type: String           // "exec", "prompt", "break_taken", "break_skipped"
        let duration: Int?         // seconds
        let exitCode: Int?
        let isLateNight: Bool      // 00:00-05:00
    }

    struct DailySummary: Codable {
        var date: String                 // YYYY-MM-DD
        var totalWorkMinutes: Int = 0
        var breakCount: Int = 0
        var breakComplianceRate: Double = 0  // breaks taken / breaks suggested
        var lateNightSessions: Int = 0
        var longestContinuousStreak: Int = 0 // minutes
        var sessionCount: Int = 0        // number of exec events
        var tasksCompleted: Int = 0      // prompt events with exit=0
        var remindersSuggested: Int = 0
        var remindersTaken: Int = 0
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dataDir = appSupport.appendingPathComponent("PixelPal/patterns", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        statsPath = appSupport.appendingPathComponent("PixelPal/work-stats.json").path

        let today = Self.dateString(Date())
        todaySummary = DailySummary(date: today)
        workStats = WorkStats()

        loadTodaySummary()
        loadWorkStats()
    }

    // MARK: - Record events

    func recordExec(timestamp: Date) {
        let isLate = isLateNight(timestamp)
        let event = WorkEvent(timestamp: timestamp, type: "exec", duration: nil, exitCode: nil, isLateNight: isLate)
        eventLog.append(event)
        todaySummary.sessionCount += 1
        if isLate {
            todaySummary.lateNightSessions += 1
            workStats.lateNightSessions += 1
        }
        save()
    }

    func recordPrompt(timestamp: Date, exitCode: Int, duration: Int) {
        let event = WorkEvent(timestamp: timestamp, type: "prompt", duration: duration, exitCode: exitCode, isLateNight: isLateNight(timestamp))
        eventLog.append(event)
        todaySummary.totalWorkMinutes += duration / 60
        workStats.totalWorkMinutes += duration / 60

        if exitCode == 0 && duration > 1 {
            todaySummary.tasksCompleted += 1
            workStats.tasksCompleted += 1
        }

        // Track longest continuous streak
        let currentStreak = duration / 60
        if currentStreak > todaySummary.longestContinuousStreak {
            todaySummary.longestContinuousStreak = currentStreak
        }

        save()
    }

    func recordBreakTaken() {
        let event = WorkEvent(timestamp: Date(), type: "break_taken", duration: nil, exitCode: nil, isLateNight: false)
        eventLog.append(event)
        todaySummary.breakCount += 1
        todaySummary.remindersTaken += 1
        workStats.breaksTaken += 1
        updateComplianceRate()
        save()
    }

    func recordBreakSkipped() {
        let event = WorkEvent(timestamp: Date(), type: "break_skipped", duration: nil, exitCode: nil, isLateNight: false)
        eventLog.append(event)
        todaySummary.remindersSuggested += 1
        updateComplianceRate()
        save()
    }

    func recordReminderSuggested() {
        todaySummary.remindersSuggested += 1
        updateComplianceRate()
        save()
    }

    func recordDayUsed() {
        let today = Self.dateString(Date())
        if todaySummary.date != today {
            // New day — archive yesterday, start fresh
            saveDailySummary(todaySummary)
            todaySummary = DailySummary(date: today)
            eventLog = []
        }
        workStats.totalDaysUsed += 1
        save()
    }

    // MARK: - Weekly report data

    func weekSummaries(count: Int = 7) -> [DailySummary] {
        var summaries: [DailySummary] = []
        let cal = Calendar.current
        for dayOffset in (0..<count).reversed() {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateStr = Self.dateString(date)
            if let summary = loadDailySummary(dateStr) {
                summaries.append(summary)
            }
        }
        return summaries
    }

    func weekReport() -> WeekReport {
        let summaries = weekSummaries()
        return WeekReport(
            totalWorkMinutes: summaries.reduce(0) { $0 + $1.totalWorkMinutes },
            totalBreaks: summaries.reduce(0) { $0 + $1.breakCount },
            avgBreakCompliance: summaries.isEmpty ? 0 : summaries.reduce(0.0) { $0 + $1.breakComplianceRate } / Double(summaries.count),
            lateNightCount: summaries.reduce(0) { $0 + $1.lateNightSessions },
            longestStreak: summaries.map(\.longestContinuousStreak).max() ?? 0,
            tasksCompleted: summaries.reduce(0) { $0 + $1.tasksCompleted },
            daysActive: summaries.count
        )
    }

    struct WeekReport {
        let totalWorkMinutes: Int
        let totalBreaks: Int
        let avgBreakCompliance: Double
        let lateNightCount: Int
        let longestStreak: Int
        let tasksCompleted: Int
        let daysActive: Int

        var totalWorkHours: Double { Double(totalWorkMinutes) / 60.0 }
    }

    // MARK: - Helpers

    private func isLateNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 0 && hour < 5
    }

    private func updateComplianceRate() {
        if todaySummary.remindersSuggested > 0 {
            todaySummary.breakComplianceRate = Double(todaySummary.remindersTaken) / Double(todaySummary.remindersSuggested)
        }
    }

    static func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    // MARK: - Persistence

    private func save() {
        saveDailySummary(todaySummary)
        saveWorkStats()
    }

    private func saveDailySummary(_ summary: DailySummary) {
        let path = dataDir.appendingPathComponent("\(summary.date).json")
        if let data = try? JSONEncoder().encode(summary) {
            try? data.write(to: path)
        }
    }

    private func loadDailySummary(_ dateStr: String) -> DailySummary? {
        let path = dataDir.appendingPathComponent("\(dateStr).json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(DailySummary.self, from: data)
    }

    private func loadTodaySummary() {
        let today = Self.dateString(Date())
        if let existing = loadDailySummary(today) {
            todaySummary = existing
        }
    }

    private func saveWorkStats() {
        if let data = try? JSONEncoder().encode(workStats) {
            try? data.write(to: URL(fileURLWithPath: statsPath))
        }
    }

    private func loadWorkStats() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statsPath)) else { return }
        workStats = (try? JSONDecoder().decode(WorkStats.self, from: data)) ?? WorkStats()
    }
}
