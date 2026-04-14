import Testing
import Foundation
@testable import PixelPalCore

@Suite("Character accent colors")
struct AccentColorTests {

    @Test("Every character has a non-empty, 6-hex-digit accent")
    func allCharactersHaveAccent() {
        for profile in DiscoveryManager.allCharacters {
            let hex = profile.accentHex.hasPrefix("#")
                ? String(profile.accentHex.dropFirst())
                : profile.accentHex
            #expect(hex.count == 6, "\(profile.id) accent must be 6 hex digits — got '\(profile.accentHex)'")
            #expect(UInt32(hex, radix: 16) != nil, "\(profile.id) accent '\(profile.accentHex)' is not parseable hex")
        }
    }

    @Test("Accents are distinct across all 9 characters (no visual collisions)")
    func accentsAreUnique() {
        let hexes = DiscoveryManager.allCharacters.map { $0.accentHex.lowercased() }
        #expect(Set(hexes).count == hexes.count, "Duplicate accent color across characters")
    }

    @Test("Accents stay in readable mid-brightness range (not pure black / white / neon)")
    func accentsAreReadable() {
        for profile in DiscoveryManager.allCharacters {
            let hex = profile.accentHex.hasPrefix("#")
                ? String(profile.accentHex.dropFirst())
                : profile.accentHex
            guard let v = UInt32(hex, radix: 16) else { continue }
            let r = Double((v >> 16) & 0xFF)
            let g = Double((v >> 8) & 0xFF)
            let b = Double(v & 0xFF)
            let brightness = (r + g + b) / 3.0
            #expect(brightness > 40, "\(profile.id) too dark (\(brightness))")
            #expect(brightness < 230, "\(profile.id) too bright (\(brightness))")
        }
    }
}
