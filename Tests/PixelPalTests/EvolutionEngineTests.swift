import Testing
import Foundation
@testable import PixelPalCore

@Suite("EvolutionEngine")
struct EvolutionEngineTests {

    @Test("Stage progression from days")
    func stageFromDays() {
        #expect(EvolutionStage.from(days: 0) == .newborn)
        #expect(EvolutionStage.from(days: 6) == .newborn)
        #expect(EvolutionStage.from(days: 7) == .familiar)
        #expect(EvolutionStage.from(days: 13) == .familiar)
        #expect(EvolutionStage.from(days: 14) == .settled)
        #expect(EvolutionStage.from(days: 29) == .settled)
        #expect(EvolutionStage.from(days: 30) == .bonded)
        #expect(EvolutionStage.from(days: 59) == .bonded)
        #expect(EvolutionStage.from(days: 60) == .devoted)
        #expect(EvolutionStage.from(days: 89) == .devoted)
        #expect(EvolutionStage.from(days: 90) == .eternal)
        #expect(EvolutionStage.from(days: 999) == .eternal)
    }

    @Test("Stage ordering")
    func stageOrdering() {
        #expect(EvolutionStage.newborn < .familiar)
        #expect(EvolutionStage.familiar < .settled)
        #expect(EvolutionStage.settled < .bonded)
        #expect(EvolutionStage.bonded < .devoted)
        #expect(EvolutionStage.devoted < .eternal)
    }

    @Test("Labels are non-empty")
    func labels() {
        for stage in [EvolutionStage.newborn, .familiar, .settled, .bonded, .devoted, .eternal] {
            #expect(!stage.label.isEmpty)
        }
    }

    @Test("Sprite suffix is nil for newborn, non-nil for others")
    func spriteSuffix() {
        #expect(EvolutionStage.newborn.spriteSuffix == nil)
        #expect(EvolutionStage.familiar.spriteSuffix == "evo1")
        #expect(EvolutionStage.eternal.spriteSuffix == "evo5")
    }

    @MainActor
    @Test("Milestone fires once per stage transition")
    func milestoneFiresOnce() {
        let engine = EvolutionEngine()

        // Day 0 → no milestone (already newborn)
        let m1 = engine.checkMilestone(characterId: "spike", evolutionDays: 0)
        #expect(m1 == nil)

        // Day 7 → familiar milestone
        let m2 = engine.checkMilestone(characterId: "spike", evolutionDays: 7)
        #expect(m2 == .familiar)

        // Day 8 → no new milestone (still familiar)
        let m3 = engine.checkMilestone(characterId: "spike", evolutionDays: 8)
        #expect(m3 == nil)

        // Day 14 → settled milestone
        let m4 = engine.checkMilestone(characterId: "spike", evolutionDays: 14)
        #expect(m4 == .settled)

        // Day 14 again → no repeat
        let m5 = engine.checkMilestone(characterId: "spike", evolutionDays: 14)
        #expect(m5 == nil)
    }

    @MainActor
    @Test("Different characters tracked independently")
    func independentTracking() {
        let engine = EvolutionEngine()

        let m1 = engine.checkMilestone(characterId: "spike", evolutionDays: 7)
        #expect(m1 == .familiar)

        // Dash at day 7 should also fire (independent tracking)
        let m2 = engine.checkMilestone(characterId: "dash", evolutionDays: 7)
        #expect(m2 == .familiar)
    }
}
