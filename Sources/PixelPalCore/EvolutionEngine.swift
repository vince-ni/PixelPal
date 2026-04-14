import Foundation

/// Passive evolution system — Animal Crossing philosophy.
/// Characters evolve based on cumulative companionship days, not behavior.
/// Growth cannot be accelerated by paying. Absence never causes degradation.
public enum EvolutionStage: Int, Comparable {
    case newborn = 0     // Day 0-6: just discovered
    case familiar = 1    // Day 7-13: learns user's name
    case settled = 2     // Day 14-29: new idle animation variant
    case bonded = 3      // Day 30-59: color palette warms
    case devoted = 4     // Day 60-89: small accessory appears
    case eternal = 5     // Day 90+: full visual evolution

    public static func < (lhs: EvolutionStage, rhs: EvolutionStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func from(days: Int) -> EvolutionStage {
        switch days {
        case ..<7: return .newborn
        case 7..<14: return .familiar
        case 14..<30: return .settled
        case 30..<60: return .bonded
        case 60..<90: return .devoted
        default: return .eternal
        }
    }

    public var label: String {
        switch self {
        case .newborn: return "New"
        case .familiar: return "Familiar"
        case .settled: return "Settled"
        case .bonded: return "Bonded"
        case .devoted: return "Devoted"
        case .eternal: return "Eternal"
        }
    }

    /// Sprite suffix for loading evolution-specific assets.
    /// Returns nil for newborn (uses base sprite).
    public var spriteSuffix: String? {
        switch self {
        case .newborn: return nil
        case .familiar: return "evo1"
        case .settled: return "evo2"
        case .bonded: return "evo3"
        case .devoted: return "evo4"
        case .eternal: return "evo5"
        }
    }

    /// Day threshold for this stage
    public var dayThreshold: Int {
        switch self {
        case .newborn: return 0
        case .familiar: return 7
        case .settled: return 14
        case .bonded: return 30
        case .devoted: return 60
        case .eternal: return 90
        }
    }
}

/// Tracks evolution milestones and triggers speech/visual changes.
@MainActor
public final class EvolutionEngine {
    private var lastMilestones: [String: EvolutionStage] = [:]

    /// Check if a character just crossed an evolution milestone.
    /// Returns the new stage if a milestone was just reached, nil otherwise.
    public init() {}

    public func checkMilestone(characterId: String, evolutionDays: Int) -> EvolutionStage? {
        let currentStage = EvolutionStage.from(days: evolutionDays)
        let previousStage = lastMilestones[characterId] ?? .newborn

        if currentStage > previousStage {
            lastMilestones[characterId] = currentStage
            return currentStage
        }

        // Sync tracking without triggering
        if lastMilestones[characterId] == nil {
            lastMilestones[characterId] = currentStage
        }

        return nil
    }
}
