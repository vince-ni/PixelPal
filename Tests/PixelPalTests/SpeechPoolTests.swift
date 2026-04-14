import Testing
import Foundation
@testable import PixelPalCore

@Suite("SpeechPool")
struct SpeechPoolTests {

    @Test("Every character has lines for core contexts")
    func coreContextsCovered() {
        let characters = ["spike", "dash", "badge", "ramble", "rush", "blunt", "meltdown", "dragon", "slime"]
        let contexts: [SpeechPool.Context] = [.celebrate, .nudgeEye, .greeting]

        for char in characters {
            for ctx in contexts {
                let line = SpeechPool.line(character: char, context: ctx)
                #expect(line != nil, "Character '\(char)' missing line for context")
            }
        }
    }

    @Test("Evolution lines exist for spike at all milestones")
    func spikeEvolutionLines() {
        let milestones = [7, 14, 30, 60, 90]
        for day in milestones {
            let line = SpeechPool.line(character: "spike", context: .evolution(day))
            #expect(line != nil, "Spike missing evolution line for day \(day)")
        }
    }

    @Test("Every character has a state label for every core state")
    func stateLabelsCovered() {
        let characters = ["spike", "dash", "badge", "ramble", "rush", "blunt", "meltdown", "dragon", "slime"]
        let states = ["idle", "working", "celebrate", "nudge", "comfort"]
        for char in characters {
            for state in states {
                let label = SpeechPool.stateLabel(character: char, state: state)
                #expect(!label.isEmpty, "Character '\(char)' has empty state label for '\(state)'")
            }
        }
    }

    @Test("Unknown character falls back to neutral state labels, not rawValue leak")
    func unknownCharacterStateFallback() {
        #expect(SpeechPool.stateLabel(character: "ghost", state: "idle") == "Here")
        #expect(SpeechPool.stateLabel(character: "ghost", state: "working") == "Watching you work")
        #expect(SpeechPool.stateLabel(character: "ghost", state: "nudge") == "Looking out for you")
    }

    @Test("Every character has a stage label for every evolution stage")
    func stageLabelsCovered() {
        let characters = ["spike", "dash", "badge", "ramble", "rush", "blunt", "meltdown", "dragon", "slime"]
        let stages: [EvolutionStage] = [.newborn, .familiar, .settled, .bonded, .devoted, .eternal]
        for char in characters {
            for stage in stages {
                let label = SpeechPool.stageLabel(character: char, stage: stage)
                #expect(!label.isEmpty, "Character '\(char)' has empty stage label for \(stage)")
            }
        }
    }

    @Test("Unknown character stage label falls back to engineering name, not empty")
    func unknownCharacterStageFallback() {
        #expect(SpeechPool.stageLabel(character: "ghost", stage: .bonded) == "Bonded")
        #expect(SpeechPool.stageLabel(character: "ghost", stage: .newborn) == "New")
    }

    @Test("Known character stage label is distinct from engineering name")
    func spikeStageDistinct() {
        #expect(SpeechPool.stageLabel(character: "spike", stage: .bonded) != "Bonded")
        #expect(SpeechPool.stageLabel(character: "spike", stage: .bonded).contains("friend"))
    }

    @Test("Known character returns character-voiced label, not neutral fallback")
    func spikeLabelDistinct() {
        let spikeIdle = SpeechPool.stateLabel(character: "spike", state: "idle")
        let neutralIdle = SpeechPool.stateLabel(character: "ghost", state: "idle")
        #expect(spikeIdle != neutralIdle)
        #expect(spikeIdle.contains("Here for"))
    }

    @Test("Unknown character returns nil")
    func unknownCharacter() {
        let line = SpeechPool.line(character: "nonexistent", context: .celebrate)
        #expect(line == nil)
    }

    @Test("Lines are non-empty strings")
    func linesNonEmpty() {
        let characters = ["spike", "dash", "badge", "dragon", "slime"]
        for char in characters {
            if let line = SpeechPool.line(character: char, context: .celebrate) {
                #expect(!line.isEmpty)
            }
        }
    }

    @Test("Locale detection property exists")
    func localeDetection() {
        // isChinese should be a boolean (true or false depending on test environment)
        let _ = SpeechPool.isChinese // just verify it doesn't crash
    }
}
