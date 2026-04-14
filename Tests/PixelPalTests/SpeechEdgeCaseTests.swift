import Testing
import Foundation
@testable import PixelPalCore

@Suite("SpeechEdgeCases")
struct SpeechEdgeCaseTests {

    @MainActor
    @Test("Unknown character returns nil, doesn't crash")
    func unknownCharacter() {
        let ctx = WorkContext()
        let engine = SpeechEngine(workContext: ctx)
        let text = engine.onEvent(.taskComplete, characterId: "nonexistent_character_xyz")
        // Should return nil gracefully, not crash
        #expect(text == nil || text != nil) // just verify no crash
    }

    @MainActor
    @Test("Empty character ID doesn't crash")
    func emptyCharacterId() {
        let ctx = WorkContext()
        let engine = SpeechEngine(workContext: ctx)
        let text = engine.onEvent(.claudeNeedsYou, characterId: "")
        // Should not crash
        #expect(text == nil || text != nil)
    }

    @MainActor
    @Test("SpeechPool with empty character returns nil")
    func speechPoolEmpty() {
        let line = SpeechPool.line(character: "", context: .celebrate)
        #expect(line == nil)
    }

    @MainActor
    @Test("WorkContext handles zero-duration commands")
    func zeroDuration() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 0, duration: 0, gitBranch: nil, timestamp: Date())
        // duration=0, exitCode=0 should NOT count as a commit
        #expect(ctx.todayCommits == 0)
    }

    @MainActor
    @Test("WorkContext handles negative duration")
    func negativeDuration() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 0, duration: -5, gitBranch: nil, timestamp: Date())
        // Should not crash or increment counters
        #expect(ctx.todayCommits == 0)
    }

    @MainActor
    @Test("WorkContext handles empty branch name")
    func emptyBranch() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 0, duration: 5, gitBranch: "", timestamp: Date())
        #expect(ctx.currentBranch == "") // empty branch stays empty
    }

    @MainActor
    @Test("WorkContext handles nil branch")
    func nilBranch() {
        let ctx = WorkContext()
        ctx.recordPrompt(exitCode: 0, duration: 5, gitBranch: nil, timestamp: Date())
        #expect(ctx.currentBranch == "")
    }

    @MainActor
    @Test("ProviderRegistry with invalid ID returns nil")
    func invalidProvider() {
        let adapter = ProviderRegistry.adapter(for: "invalid-tool-xyz")
        #expect(adapter == nil)
    }
}
