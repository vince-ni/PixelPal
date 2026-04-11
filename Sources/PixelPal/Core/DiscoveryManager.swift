import Foundation

/// Manages character discovery conditions and companion log state.
/// Characters "come to you" based on your work journey — not purchased or randomly drawn.
struct CharacterProfile {
    let id: String
    let name: String
    let species: String
    let style: String              // Simple / Expressive / Complex / Enigmatic
    let hint: String               // shown in companion log before discovery
    let greeting: String           // first words when discovered

    // Discovery condition is evaluated by DiscoveryManager, not stored here
}

struct DiscoveredCharacter: Codable {
    let characterId: String
    var discoveredAt: Date
    var evolutionDays: Int         // cumulative days since discovery
    var lastSeenDate: String       // YYYY-MM-DD, for counting unique days
    var isActive: Bool             // currently selected as companion
}

@MainActor
final class DiscoveryManager: ObservableObject {
    @Published private(set) var discovered: [DiscoveredCharacter] = []

    private let persistencePath: String

    // All 9 characters defined
    static let allCharacters: [CharacterProfile] = [
        CharacterProfile(id: "spike", name: "Spike", species: "Hedgehog", style: "Simple",
                        hint: "Has been here from the start",
                        greeting: "Hi! I'm Spike. I'll keep you company!"),
        CharacterProfile(id: "dash", name: "Dash", species: "Cheetah", style: "Simple",
                        hint: "Takes time to trust you",
                        greeting: "Oh... you're here too... I guess I can stay..."),
        CharacterProfile(id: "badge", name: "Badge", species: "Golden Retriever", style: "Expressive",
                        hint: "Studying your work patterns",
                        greeting: "New user detected. Analyzing data. Hello."),
        CharacterProfile(id: "ramble", name: "Ramble", species: "Owl", style: "Expressive",
                        hint: "Waits until you've settled in",
                        greeting: "Oh finally! Did you know 73% of bugs happen when— anyway, hi!"),
        CharacterProfile(id: "rush", name: "Rush", species: "Turtle", style: "Expressive",
                        hint: "Attracted to a certain rhythm",
                        greeting: "FINALLY! Do you know how long I waited?? 47 DAYS!!!"),
        CharacterProfile(id: "blunt", name: "Blunt", species: "Fox", style: "Complex",
                        hint: "Watching your output",
                        greeting: "You've completed 50 tasks. That's a fact, not a compliment."),
        CharacterProfile(id: "meltdown", name: "Meltdown", species: "Phoenix", style: "Complex",
                        hint: "Only appears at milestones",
                        greeting: "NO!! 100 TASKS!! THIS IS INSANE!! 🔥"),
        CharacterProfile(id: "dragon", name: "...", species: "Dragon", style: "Enigmatic",
                        hint: "Only comes out at night",
                        greeting: "......"),
        CharacterProfile(id: "slime", name: ".", species: "Slime", style: "Enigmatic",
                        hint: "......",
                        greeting: ".")
    ]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pixelpalDir = appSupport.appendingPathComponent("PixelPal", isDirectory: true)
        try? FileManager.default.createDirectory(at: pixelpalDir, withIntermediateDirectories: true)
        persistencePath = pixelpalDir.appendingPathComponent("discoveries.json").path

        loadDiscoveries()
        ensureSpikeExists()
    }

    // MARK: - Discovery checks

    /// Called periodically to evaluate discovery conditions.
    /// workStats provides the data needed to check conditions.
    func evaluateDiscoveries(workStats: WorkStats) {
        let today = dateString(Date())

        // Spike: always present (Day 1)
        // Already ensured in init

        // Dash: 7 cumulative days
        if !isDiscovered("dash") && workStats.totalDaysUsed >= 7 {
            discover("dash")
        }

        // Badge: 14 cumulative days
        if !isDiscovered("badge") && workStats.totalDaysUsed >= 14 {
            discover("badge")
        }

        // Ramble: 21 cumulative days
        if !isDiscovered("ramble") && workStats.totalDaysUsed >= 21 {
            discover("ramble")
        }

        // Rush: responded to 20 break reminders
        if !isDiscovered("rush") && workStats.breaksTaken >= 20 {
            discover("rush")
        }

        // Blunt: completed 50 tasks
        if !isDiscovered("blunt") && workStats.tasksCompleted >= 50 {
            discover("blunt")
        }

        // Meltdown: completed 100 tasks
        if !isDiscovered("meltdown") && workStats.tasksCompleted >= 100 {
            discover("meltdown")
        }

        // Dragon: worked past midnight 3 times
        if !isDiscovered("dragon") && workStats.lateNightSessions >= 3 {
            discover("dragon")
        }

        // Slime: all other 8 discovered
        if !isDiscovered("slime") && discovered.count >= 8 {
            discover("slime")
        }

        // Update evolution days for discovered characters
        for i in discovered.indices {
            if discovered[i].lastSeenDate != today {
                discovered[i].evolutionDays += 1
                discovered[i].lastSeenDate = today
            }
        }

        saveDiscoveries()
    }

    // MARK: - Character access

    var activeCharacter: CharacterProfile {
        let activeId = discovered.first(where: { $0.isActive })?.characterId ?? "spike"
        return Self.allCharacters.first(where: { $0.id == activeId }) ?? Self.allCharacters[0]
    }

    func setActive(_ characterId: String) {
        guard isDiscovered(characterId) else { return }
        for i in discovered.indices {
            discovered[i].isActive = (discovered[i].characterId == characterId)
        }
        saveDiscoveries()
    }

    func isDiscovered(_ characterId: String) -> Bool {
        discovered.contains(where: { $0.characterId == characterId })
    }

    func profile(for characterId: String) -> CharacterProfile? {
        Self.allCharacters.first(where: { $0.id == characterId })
    }

    /// Returns newly discovered character ID if a discovery just happened, nil otherwise.
    /// Used by the UI to trigger discovery animation.
    var pendingDiscovery: String? = nil

    func consumePendingDiscovery() -> String? {
        let d = pendingDiscovery
        pendingDiscovery = nil
        return d
    }

    // MARK: - Internal

    private func discover(_ characterId: String) {
        guard !isDiscovered(characterId) else { return }
        let entry = DiscoveredCharacter(
            characterId: characterId,
            discoveredAt: Date(),
            evolutionDays: 0,
            lastSeenDate: dateString(Date()),
            isActive: discovered.isEmpty // first character is auto-active
        )
        discovered.append(entry)
        pendingDiscovery = characterId
        saveDiscoveries()
        print("[PixelPal] New character discovered: \(characterId)!")
    }

    private func ensureSpikeExists() {
        if !isDiscovered("spike") {
            discover("spike")
            // Consume the pending so Spike doesn't trigger a "discovery" animation
            _ = consumePendingDiscovery()
        }
    }

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    // MARK: - Persistence

    private func saveDiscoveries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(discovered) {
            try? data.write(to: URL(fileURLWithPath: persistencePath))
        }
    }

    private func loadDiscoveries() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: persistencePath)) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        discovered = (try? decoder.decode([DiscoveredCharacter].self, from: data)) ?? []
    }
}

/// Work statistics used to evaluate discovery conditions.
/// Accumulated by StateMachine and passed to DiscoveryManager.
struct WorkStats: Codable {
    var totalDaysUsed: Int = 0
    var breaksTaken: Int = 0
    var tasksCompleted: Int = 0        // claude_stop events
    var lateNightSessions: Int = 0     // work events between 00:00-05:00
    var totalWorkMinutes: Int = 0
}
