import Testing
import Foundation
@testable import PixelPalCore

@Suite("StateMachine")
struct StateMachineTests {

    @MainActor
    @Test("Starts in idle state")
    func initialState() {
        let sm = StateMachine()
        #expect(sm.state == .idle)
        #expect(sm.showBubble == false)
        #expect(sm.workMinutes == 0)
    }

    @MainActor
    @Test("Exec event transitions to working")
    func execTransition() {
        let sm = StateMachine()
        let event = ShellEvent(kind: .exec, timestamp: Date().timeIntervalSince1970, command: "swift build", exitCode: nil, duration: nil, pwd: nil, gitBranch: nil)
        sm.handleEvent(event)
        #expect(sm.state == .working)
    }

    @MainActor
    @Test("Failed command transitions to comfort")
    func failedCommandComfort() {
        let sm = StateMachine()
        let event = ShellEvent(kind: .prompt, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: 1, duration: 5, pwd: nil, gitBranch: nil)
        sm.handleEvent(event)
        #expect(sm.state == .comfort)
    }

    @MainActor
    @Test("Short failed command does not trigger comfort")
    func shortFailureNoComfort() {
        let sm = StateMachine()
        let event = ShellEvent(kind: .prompt, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: 1, duration: 1, pwd: nil, gitBranch: nil)
        sm.handleEvent(event)
        // Should not be comfort for short failures (< 3s)
        #expect(sm.state != .comfort)
    }

    @MainActor
    @Test("Git branch updates from prompt event")
    func gitBranchUpdate() {
        let sm = StateMachine()
        let event = ShellEvent(kind: .prompt, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: 0, duration: 2, pwd: nil, gitBranch: "feature/auth")
        sm.handleEvent(event)
        #expect(sm.gitBranch == "feature/auth")
    }

    @MainActor
    @Test("Claude stop transitions to celebrate")
    func claudeStopCelebrate() {
        let sm = StateMachine()
        let event = ShellEvent(kind: .claude_stop, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: nil, duration: nil, pwd: nil, gitBranch: nil)
        sm.handleEvent(event)
        #expect(sm.state == .celebrate)
    }

    @MainActor
    @Test("Work minutes accumulate from prompt duration")
    func workMinutesAccumulate() {
        let sm = StateMachine()
        let event1 = ShellEvent(kind: .prompt, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: 0, duration: 120, pwd: nil, gitBranch: nil)
        sm.handleEvent(event1)
        let event2 = ShellEvent(kind: .prompt, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: 0, duration: 180, pwd: nil, gitBranch: nil)
        sm.handleEvent(event2)
        #expect(sm.workMinutes == 5) // 120/60 + 180/60
    }

    @MainActor
    @Test("Overload protection: 2 dismissals in 5 min silences bubbles")
    func overloadProtection() {
        let sm = StateMachine()
        sm.userDismissedBubble()
        sm.userDismissedBubble()
        // After 2 quick dismissals, showReminderBubble should be suppressed
        sm.showReminderBubble("test")
        // The silentUntil is set internally, bubble should not show
        // (canShowBubble returns false)
        #expect(sm.showBubble == false)
    }

    @MainActor
    @Test("Events forwarded to WorkContext when set")
    func workContextIntegration() {
        let sm = StateMachine()
        let ctx = WorkContext()
        sm.workContext = ctx

        let event = ShellEvent(kind: .prompt, timestamp: Date().timeIntervalSince1970, command: nil, exitCode: 1, duration: 5, pwd: nil, gitBranch: "main")
        sm.handleEvent(event)

        #expect(ctx.consecutiveErrors == 1)
        #expect(ctx.currentBranch == "main")
    }
}
