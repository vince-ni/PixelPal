import Testing
import Foundation
@testable import PixelPalCore

@Suite("EvolutionBoundary")
struct EvolutionBoundaryTests {
    @Test("Negative days should be newborn, not eternal")
    func negativeDays() {
        let neg = EvolutionStage.from(days: -1)
        #expect(neg == .newborn, "days=-1 gave \(neg), expected newborn")
    }

    @Test("INT_MAX should be eternal")
    func maxInt() {
        let huge = EvolutionStage.from(days: Int.max)
        #expect(huge == .eternal)
    }
}
