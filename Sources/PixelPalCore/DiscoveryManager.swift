import Foundation

/// Manages character discovery conditions and companion log state.
/// Characters "come to you" based on your work journey — not purchased or randomly drawn.
public struct CharacterProfile {
    public let id: String
    public let name: String
    public let species: String
    public let style: String              // Simple / Expressive / Complex / Enigmatic
    public let hint: String               // shown in companion log before discovery
    public let greeting: String           // first words when discovered
    public let accentHex: String          // per-character panel accent color (#RRGGBB)

    public init(id: String, name: String, species: String, style: String,
                hint: String, greeting: String, accentHex: String) {
        self.id = id
        self.name = name
        self.species = species
        self.style = style
        self.hint = hint
        self.greeting = greeting
        self.accentHex = accentHex
    }

    // Discovery condition is evaluated by DiscoveryManager, not stored here
}

public struct DiscoveredCharacter: Codable {
    public let characterId: String
    public var discoveredAt: Date
    public var evolutionDays: Int         // cumulative days since discovery
    public var lastSeenDate: String       // YYYY-MM-DD, for counting unique days
    public var isActive: Bool             // currently selected as companion
}

@MainActor
public final class DiscoveryManager: ObservableObject {
    @Published public private(set) var discovered: [DiscoveredCharacter] = []

    private let persistencePath: String

    // All 9 characters defined. Accent colors are chosen to work against
    // both light and dark panel backgrounds (mid-brightness, saturated).
    public static let allCharacters: [CharacterProfile] = [
        CharacterProfile(id: "spike", name: "Spike", species: "Hedgehog", style: "Simple",
                        hint: "Has been here from the start",
                        greeting: "Hi! I'm Spike. I'll keep you company!",
                        accentHex: "#FF8C42"),
        CharacterProfile(id: "dash", name: "Dash", species: "Cheetah", style: "Simple",
                        hint: "Takes time to trust you",
                        greeting: "Oh... you're here too... I guess I can stay...",
                        accentHex: "#2EC4B6"),
        CharacterProfile(id: "badge", name: "Badge", species: "Golden Retriever", style: "Expressive",
                        hint: "Studying your work patterns",
                        greeting: "New user detected. Analyzing data. Hello.",
                        accentHex: "#E2B93B"),
        CharacterProfile(id: "ramble", name: "Ramble", species: "Owl", style: "Expressive",
                        hint: "Waits until you've settled in",
                        greeting: "Oh finally! Did you know 73% of bugs happen when— anyway, hi!",
                        accentHex: "#9B5DE5"),
        CharacterProfile(id: "rush", name: "Rush", species: "Turtle", style: "Expressive",
                        hint: "Attracted to a certain rhythm",
                        greeting: "FINALLY! Do you know how long I waited?? 47 DAYS!!!",
                        accentHex: "#70C13E"),
        CharacterProfile(id: "blunt", name: "Blunt", species: "Fox", style: "Complex",
                        hint: "Watching your output",
                        greeting: "You've completed 50 tasks. That's a fact, not a compliment.",
                        accentHex: "#3A6EA5"),
        CharacterProfile(id: "meltdown", name: "Meltdown", species: "Phoenix", style: "Complex",
                        hint: "Only appears at milestones",
                        greeting: "NO!! 100 TASKS!! THIS IS INSANE!! 🔥",
                        accentHex: "#E63946"),
        CharacterProfile(id: "dragon", name: "...", species: "Dragon", style: "Enigmatic",
                        hint: "Only comes out at night",
                        greeting: "......",
                        accentHex: "#6A4C93"),
        CharacterProfile(id: "slime", name: ".", species: "Slime", style: "Enigmatic",
                        hint: "......",
                        greeting: ".",
                        accentHex: "#8D99AE")
    ]

    private var cloudSync: CloudSync?

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pixelpalDir = appSupport.appendingPathComponent("PixelPal", isDirectory: true)
        try? FileManager.default.createDirectory(at: pixelpalDir, withIntermediateDirectories: true)
        persistencePath = pixelpalDir.appendingPathComponent("discoveries.json").path

        loadDiscoveries()

        // If local data is empty, try restoring from cloud
        if discovered.isEmpty {
            let sync = CloudSync()
            cloudSync = sync
            if let restored = sync.restoreDiscoveries(), !restored.isEmpty {
                discovered = restored
                saveDiscoveries()
            }
        } else {
            cloudSync = CloudSync()
        }

        ensureSpikeExists()

        // Observe iCloud changes from other devices
        cloudSync?.startObserving { [weak self] remoteDiscoveries in
            guard let self else { return }
            // Merge: keep whichever has more discoveries
            if remoteDiscoveries.count > self.discovered.count {
                self.discovered = remoteDiscoveries
                self.saveDiscoveries()
            }
        }
    }

    /// Test-only init: uses a temp path, skips cloud sync, starts fresh.
    public init(testPersistencePath: String) {
        persistencePath = testPersistencePath
        ensureSpikeExists()
    }

    // MARK: - Discovery checks

    /// Called periodically to evaluate discovery conditions.
    /// workStats provides the data needed to check conditions.
    public func evaluateDiscoveries(workStats: WorkStats) {
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

    public var activeCharacter: CharacterProfile {
        let activeId = discovered.first(where: { $0.isActive })?.characterId ?? "spike"
        return Self.allCharacters.first(where: { $0.id == activeId }) ?? Self.allCharacters[0]
    }

    /// Debug: discover all characters at once. For testing only.
    public func discoverAll() {
        for character in Self.allCharacters where !isDiscovered(character.id) {
            discover(character.id)
        }
        // Consume all pending so they don't all trigger animations at once
        pendingDiscovery = nil
        saveDiscoveries()
    }

    public func setActive(_ characterId: String) {
        guard isDiscovered(characterId) else { return }
        for i in discovered.indices {
            discovered[i].isActive = (discovered[i].characterId == characterId)
        }
        saveDiscoveries()
    }

    public func isDiscovered(_ characterId: String) -> Bool {
        discovered.contains(where: { $0.characterId == characterId })
    }

    public func profile(for characterId: String) -> CharacterProfile? {
        Self.allCharacters.first(where: { $0.id == characterId })
    }

    /// Returns newly discovered character ID if a discovery just happened, nil otherwise.
    /// Used by the UI to trigger discovery animation.
    public var pendingDiscovery: String? = nil

    public func consumePendingDiscovery() -> String? {
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
            // L1: Local
            try? data.write(to: URL(fileURLWithPath: persistencePath))
            // L2 + L3: Cloud
            cloudSync?.syncDiscoveries(discovered)
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
public struct WorkStats: Codable {
    public var totalDaysUsed: Int = 0
    public var breaksTaken: Int = 0
    public var tasksCompleted: Int = 0        // claude_stop events
    public var lateNightSessions: Int = 0     // work events between 00:00-05:00
    public var totalWorkMinutes: Int = 0

    public init(totalDaysUsed: Int = 0, breaksTaken: Int = 0, tasksCompleted: Int = 0, lateNightSessions: Int = 0, totalWorkMinutes: Int = 0) {
        self.totalDaysUsed = totalDaysUsed
        self.breaksTaken = breaksTaken
        self.tasksCompleted = tasksCompleted
        self.lateNightSessions = lateNightSessions
        self.totalWorkMinutes = totalWorkMinutes
    }
}
