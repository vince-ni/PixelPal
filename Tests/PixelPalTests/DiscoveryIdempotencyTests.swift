import Testing
import Foundation
@testable import PixelPalCore

@Suite("DiscoveryIdempotency")
struct DiscoveryIdempotencyTests {

    @MainActor
    private func freshManager() -> DiscoveryManager {
        let tmp = NSTemporaryDirectory() + "pixelpal_idem_\(UUID().uuidString).json"
        return DiscoveryManager(testPersistencePath: tmp)
    }

    @MainActor
    @Test("evaluateDiscoveries called twice doesn't duplicate characters")
    func noDuplication() {
        let dm = freshManager()
        let stats = WorkStats(totalDaysUsed: 100, breaksTaken: 50, tasksCompleted: 200, lateNightSessions: 5, totalWorkMinutes: 5000)
        dm.evaluateDiscoveries(workStats: stats)
        let count1 = dm.discovered.count
        dm.evaluateDiscoveries(workStats: stats)
        let count2 = dm.discovered.count
        #expect(count1 == count2, "Double evaluation created duplicates: \(count1) → \(count2)")
    }

    @MainActor
    @Test("discoverAll called twice doesn't duplicate")
    func discoverAllIdempotent() {
        let dm = freshManager()
        dm.discoverAll()
        let count1 = dm.discovered.count
        dm.discoverAll()
        let count2 = dm.discovered.count
        #expect(count1 == count2)
        #expect(count1 == 9)
    }
}
