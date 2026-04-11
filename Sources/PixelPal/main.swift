import AppKit
import SwiftUI

// MARK: - Menu Bar Controller

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let stateMachine: StateMachine
    private let sessionManager: SessionManager
    private let discoveryManager: DiscoveryManager
    private let workPatternStore: WorkPatternStore
    private let reminderEngine: ReminderEngine
    private let bubbleController = BubbleWindowController()
    private let floatingCharacter = FloatingCharacterController()
    private var animationTimer: Timer?
    private var currentFrames: [NSImage] = []
    private var frameIndex = 0
    private var popover = NSPopover()
    private var stateObserver: Timer?

    init(stateMachine: StateMachine,
         sessionManager: SessionManager,
         discoveryManager: DiscoveryManager,
         workPatternStore: WorkPatternStore,
         reminderEngine: ReminderEngine) {
        self.stateMachine = stateMachine
        self.sessionManager = sessionManager
        self.discoveryManager = discoveryManager
        self.workPatternStore = workPatternStore
        self.reminderEngine = reminderEngine
        super.init()
        setupStatusItem()
        setupPopover()
        setupFloatingCharacter()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        switchAnimation(to: .idle)
    }

    private func setupPopover() {
        let view = SessionPanelView(
            sessionManager: sessionManager,
            discoveryManager: discoveryManager,
            workPatternStore: workPatternStore,
            stateMachine: stateMachine,
            onTakeBreak: { [weak self] in
                self?.reminderEngine.recordBreak()
                self?.workPatternStore.recordBreakTaken()
                self?.popover.performClose(nil)
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        popover.contentViewController = NSHostingController(rootView: view)
        popover.behavior = .transient
    }

    private func setupFloatingCharacter() {
        floatingCharacter.setup()
        floatingCharacter.onClick = { [weak self] in
            self?.statusItemClicked()
        }
        // Initial animation
        let charId = discoveryManager.activeCharacter.id
        floatingCharacter.updateAnimation(characterId: charId, state: .idle)
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - State observation

    private func observeState() {
        stateObserver = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.switchAnimation(to: self.stateMachine.state)
                self.handleBubble()
                self.handleReminder()
                self.handleDiscovery()
            }
        }
    }

    private var lastAnimatedState: CharacterState?

    private func switchAnimation(to state: CharacterState) {
        guard state != lastAnimatedState else { return }
        lastAnimatedState = state

        animationTimer?.invalidate()
        let characterId = discoveryManager.activeCharacter.id

        // Update floating character too
        floatingCharacter.updateAnimation(characterId: characterId, state: state)

        let interval: TimeInterval
        switch state {
        case .idle:
            currentFrames = SpriteSheet.frames(character: characterId, state: "idle")
            interval = 0.8
        case .working:
            currentFrames = SpriteSheet.frames(character: characterId, state: "working")
            interval = 0.2
        case .celebrate:
            currentFrames = SpriteSheet.frames(character: characterId, state: "celebrate")
            interval = 0.15
        case .nudge:
            currentFrames = SpriteSheet.frames(character: characterId, state: "nudge")
            interval = 0.6
        case .comfort:
            currentFrames = SpriteSheet.frames(character: characterId, state: "idle")
            interval = 1.0
        }

        frameIndex = 0
        updateFrame()
        if currentFrames.count > 1 {
            animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateFrame() }
            }
        }
    }

    private func updateFrame() {
        guard !currentFrames.isEmpty else { return }
        statusItem.button?.image = currentFrames[frameIndex % currentFrames.count]
        frameIndex += 1
    }

    // MARK: - Bubble management

    private var isBubbleShowing = false

    private func handleBubble() {
        if stateMachine.showBubble && !isBubbleShowing {
            isBubbleShowing = true
            let char = discoveryManager.activeCharacter
            let emoji = emojiForState(stateMachine.state)
            bubbleController.show(text: stateMachine.bubbleText, emoji: emoji, characterName: char.name) { [weak self] in
                self?.stateMachine.userDismissedBubble()
                self?.isBubbleShowing = false
                self?.bubbleController.dismiss()
            }
        } else if !stateMachine.showBubble && isBubbleShowing {
            isBubbleShowing = false
            bubbleController.dismiss()
        }
    }

    private func handleReminder() {
        if let _ = reminderEngine.currentReminder, !stateMachine.showBubble {
            stateMachine.showReminderBubble(reminderEngine.currentReminder!.message)
            workPatternStore.recordReminderSuggested()
        }
    }

    private func handleDiscovery() {
        if let newCharId = discoveryManager.consumePendingDiscovery() {
            if let profile = discoveryManager.profile(for: newCharId) {
                stateMachine.state = .celebrate
                stateMachine.showDiscoveryBubble(profile.greeting, characterName: profile.name)
            }
        }
    }

    private func emojiForState(_ state: CharacterState) -> String {
        switch state {
        case .celebrate: return "🎉"
        case .nudge: return "☕"
        case .comfort: return "💜"
        default: return "🦔"
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var socketServer: SocketServer?
    private var stateMachine: StateMachine?
    private var sessionManager: SessionManager?
    private var discoveryManager: DiscoveryManager?
    private var workPatternStore: WorkPatternStore?
    private var reminderEngine: ReminderEngine?
    private var discoveryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sm = StateMachine()
        let sessions = SessionManager()
        let discovery = DiscoveryManager()
        let patterns = WorkPatternStore()
        let reminders = ReminderEngine()

        stateMachine = sm
        sessionManager = sessions
        discoveryManager = discovery
        workPatternStore = patterns
        reminderEngine = reminders

        // Socket server: receives shell hook + Claude hook events
        let server = SocketServer { event in
            Task { @MainActor in
                sm.handleEvent(event)

                // Record to work pattern store
                switch event.kind {
                case .exec:
                    patterns.recordExec(timestamp: Date(timeIntervalSince1970: event.timestamp))
                case .prompt:
                    patterns.recordPrompt(
                        timestamp: Date(timeIntervalSince1970: event.timestamp),
                        exitCode: event.exitCode ?? 0,
                        duration: event.duration ?? 0
                    )
                case .claude_notify, .claude_stop:
                    break // handled by state machine
                }
            }
        }
        server.start()
        socketServer = server

        // Auto-configure hooks (idempotent, safe to run every launch)
        let configurator = AutoConfigurator()
        let configResult = configurator.configure()
        if !configResult.errors.isEmpty {
            print("[PixelPal] Config warnings: \(configResult.errors)")
        }

        // Record today as a used day
        patterns.recordDayUsed()

        // Menu bar UI
        menuBarController = MenuBarController(
            stateMachine: sm,
            sessionManager: sessions,
            discoveryManager: discovery,
            workPatternStore: patterns,
            reminderEngine: reminders
        )

        // Periodic discovery evaluation (every 5 minutes)
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                discovery.evaluateDiscoveries(workStats: patterns.workStats)
            }
        }
        // Initial evaluation
        Task { @MainActor in
            discovery.evaluateDiscoveries(workStats: patterns.workStats)
        }

        print("[PixelPal] Running. Character: \(discovery.activeCharacter.name). Discovered: \(discovery.discovered.count)/\(DiscoveryManager.allCharacters.count)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
