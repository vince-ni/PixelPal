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
