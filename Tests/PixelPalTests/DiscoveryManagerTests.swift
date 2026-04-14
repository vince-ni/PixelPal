import Testing
import Foundation
@testable import PixelPalCore

@Suite("DiscoveryManager")
struct DiscoveryManagerTests {

    /// Create a fresh DiscoveryManager with temp persistence (no saved state)
    @MainActor
    private func freshManager() -> DiscoveryManager {
        let tmp = NSTemporaryDirectory() + "pixelpal_test_\(UUID().uuidString).json"
        return DiscoveryManager(testPersistencePath: tmp)
    }

    @MainActor
    @Test("All 9 characters defined")
    func allCharactersDefined() {
        #expect(DiscoveryManager.allCharacters.count == 9)
        let ids = Set(DiscoveryManager.allCharacters.map(\.id))
        #expect(ids.contains("spike"))
        #expect(ids.contains("dash"))
        #expect(ids.contains("badge"))
        #expect(ids.contains("ramble"))
        #expect(ids.contains("rush"))
        #expect(ids.contains("blunt"))
        #expect(ids.contains("meltdown"))
        #expect(ids.contains("dragon"))
        #expect(ids.contains("slime"))
    }

    @MainActor
    @Test("Each character has non-empty greeting and hint")
    func characterProfilesComplete() {
        for char in DiscoveryManager.allCharacters {
            #expect(!char.name.isEmpty, "Character \(char.id) has empty name")
            #expect(!char.greeting.isEmpty, "Character \(char.id) has empty greeting")
            #expect(!char.hint.isEmpty, "Character \(char.id) has empty hint")
            #expect(!char.species.isEmpty, "Character \(char.id) has empty species")
            #expect(!char.style.isEmpty, "Character \(char.id) has empty style")
        }
    }

    @MainActor
    @Test("Spike is auto-discovered on init")
    func spikeAutoDiscovered() {
        let dm = freshManager()
        #expect(dm.isDiscovered("spike"))
        #expect(dm.activeCharacter.id == "spike")
    }

    @MainActor
    @Test("Undiscovered characters not accessible")
    func undiscoveredNotAccessible() {
        let dm = freshManager()
        // Dragon requires 3 late nights — shouldn't be discovered yet
        #expect(!dm.isDiscovered("dragon"))
        #expect(dm.profile(for: "dragon") != nil) // profile exists but not discovered
    }

    @MainActor
    @Test("Dash discovery at 7 cumulative days")
    func dashDiscoveryCondition() {
        let dm = freshManager()
        let stats = WorkStats(totalDaysUsed: 6, breaksTaken: 0, tasksCompleted: 0, lateNightSessions: 0, totalWorkMinutes: 0)
        dm.evaluateDiscoveries(workStats: stats)
        #expect(!dm.isDiscovered("dash"))

        let stats7 = WorkStats(totalDaysUsed: 7, breaksTaken: 0, tasksCompleted: 0, lateNightSessions: 0, totalWorkMinutes: 0)
        dm.evaluateDiscoveries(workStats: stats7)
        #expect(dm.isDiscovered("dash"))
    }

    @MainActor
    @Test("Rush discovery at 20 breaks taken")
    func rushDiscoveryCondition() {
        let dm = freshManager()
        let stats = WorkStats(totalDaysUsed: 30, breaksTaken: 19, tasksCompleted: 0, lateNightSessions: 0, totalWorkMinutes: 0)
        dm.evaluateDiscoveries(workStats: stats)
        #expect(!dm.isDiscovered("rush"))

        let stats20 = WorkStats(totalDaysUsed: 30, breaksTaken: 20, tasksCompleted: 0, lateNightSessions: 0, totalWorkMinutes: 0)
        dm.evaluateDiscoveries(workStats: stats20)
        #expect(dm.isDiscovered("rush"))
    }

    @MainActor
    @Test("Dragon discovery at 3 late night sessions")
    func dragonDiscoveryCondition() {
        let dm = freshManager()
        let stats = WorkStats(totalDaysUsed: 10, breaksTaken: 0, tasksCompleted: 0, lateNightSessions: 3, totalWorkMinutes: 0)
        dm.evaluateDiscoveries(workStats: stats)
        #expect(dm.isDiscovered("dragon"))
    }

    @MainActor
    @Test("Slime requires all 8 others discovered")
    func slimeRequiresAll() {
        let dm = freshManager()
        // Discover all but slime
        let stats = WorkStats(totalDaysUsed: 100, breaksTaken: 50, tasksCompleted: 200, lateNightSessions: 5, totalWorkMinutes: 5000)
        dm.evaluateDiscoveries(workStats: stats)

        // All 8 + slime should be discovered (slime triggers when others are found)
        #expect(dm.discovered.count == 9)
        #expect(dm.isDiscovered("slime"))
    }

    @MainActor
    @Test("setActive changes active character")
    func setActiveCharacter() {
        let dm = freshManager()
        dm.discoverAll()
        dm.setActive("dash")
        #expect(dm.activeCharacter.id == "dash")
    }

    @MainActor
    @Test("setActive fails silently for undiscovered character")
    func setActiveUndiscoveredFails() {
        let dm = freshManager()
        dm.setActive("dragon") // not discovered yet
        #expect(dm.activeCharacter.id == "spike") // stays on spike
    }

    @MainActor
    @Test("discoverAll unlocks all 9 characters")
    func discoverAll() {
        let dm = freshManager()
        dm.discoverAll()
        #expect(dm.discovered.count == 9)
        for char in DiscoveryManager.allCharacters {
            #expect(dm.isDiscovered(char.id))
        }
    }

    @MainActor
    @Test("pendingDiscovery consumed only once")
    func pendingDiscoveryConsumedOnce() {
        let dm = freshManager()
        let stats = WorkStats(totalDaysUsed: 7, breaksTaken: 0, tasksCompleted: 0, lateNightSessions: 0, totalWorkMinutes: 0)
        dm.evaluateDiscoveries(workStats: stats)
        // Dash should be pending
        let first = dm.consumePendingDiscovery()
        #expect(first == "dash")
        let second = dm.consumePendingDiscovery()
        #expect(second == nil)
    }
}
