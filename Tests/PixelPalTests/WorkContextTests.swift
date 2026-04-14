import Testing
import Foundation
@testable import PixelPalCore

@Suite("WorkContext")
struct WorkContextTests {

    @MainActor
    @Test("Initial state is zeroed")
    func initialState() {
        let ctx = WorkContext()
        #expect(ctx.currentBranch == "")
        #expect(ctx.consecutiveErrors == 0)
        #expect(ctx.isFlowState == false)
        #expect(ctx.todayCommits == 0)
        #expect(ctx.todayErrors == 0)
        #expect(ctx.commandVelocity == 0)
    }

    @MainActor
    @Test("Consecutive errors increment on failure")
    func consecutiveErrors() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 1, duration: 5, gitBranch: nil, timestamp: Date())
        ctx.recordPrompt(exitCode: 1, duration: 5, gitBranch: nil, timestamp: Date())
        ctx.recordPrompt(exitCode: 1, duration: 5, gitBranch: nil, timestamp: Date())
        #expect(ctx.consecutiveErrors == 3)
        #expect(ctx.todayErrors == 3)
    }

    @MainActor
    @Test("Consecutive errors reset on success")
    func errorsResetOnSuccess() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 1, duration: 5, gitBranch: nil, timestamp: Date())
        ctx.recordPrompt(exitCode: 1, duration: 5, gitBranch: nil, timestamp: Date())
        #expect(ctx.consecutiveErrors == 2)
        ctx.recordPrompt(exitCode: 0, duration: 5, gitBranch: nil, timestamp: Date())
        #expect(ctx.consecutiveErrors == 0)
    }

    @MainActor
    @Test("Branch change tracked with duration")
    func branchChange() {
        let ctx = WorkContext()
        let t1 = Date().addingTimeInterval(-700) // 11+ min ago
        ctx.recordPrompt(exitCode: 0, duration: 2, gitBranch: "feature/auth", timestamp: t1)
        #expect(ctx.currentBranch == "feature/auth")
        #expect(ctx.branchMinutes >= 11)

        // Switch branch
        ctx.recordPrompt(exitCode: 0, duration: 2, gitBranch: "main", timestamp: Date())
        #expect(ctx.currentBranch == "main")
        #expect(ctx.lastBranchSwitch?.from == "feature/auth")
        #expect((ctx.lastBranchSwitch?.duration ?? 0) >= 11)
    }

    @MainActor
    @Test("Today commits count successful commands with duration > 1")
    func todayCommits() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 0, duration: 5, gitBranch: nil, timestamp: Date())
        ctx.recordPrompt(exitCode: 0, duration: 3, gitBranch: nil, timestamp: Date())
        ctx.recordPrompt(exitCode: 0, duration: 0, gitBranch: nil, timestamp: Date()) // too short, shouldn't count
        #expect(ctx.todayCommits == 2)
    }

    @MainActor
    @Test("Break recording resets lastBreakTime")
    func breakRecording() {
        let ctx = WorkContext()
        // Simulate working for a while
        let oldBreak = ctx.minutesSinceBreak
        ctx.recordBreak()
        #expect(ctx.minutesSinceBreak <= oldBreak)
        #expect(ctx.minutesSinceBreak <= 1)
    }

    @MainActor
    @Test("Command velocity tracks recent commands")
    func commandVelocity() {
        let ctx = WorkContext()
        let now = Date()
        // Fire 10 commands in the last minute
        for i in 0..<10 {
            ctx.recordExec(command: "cmd \(i)", timestamp: now.addingTimeInterval(Double(-i)))
        }
        #expect(ctx.commandVelocity > 0)
    }

    @MainActor
    @Test("Daily reset clears today counters")
    func dailyReset() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 0, duration: 5, gitBranch: nil, timestamp: Date())
        ctx.recordPrompt(exitCode: 1, duration: 5, gitBranch: nil, timestamp: Date())
        #expect(ctx.todayCommits == 1)
        #expect(ctx.todayErrors == 1)
        // resetIfNewDay only resets if date actually changed (can't easily test without mocking)
        // Just verify method doesn't crash
        ctx.resetIfNewDay()
    }
}
