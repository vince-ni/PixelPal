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
    private var panelWindow: NSPanel?
    private var panelVisible = false
    private var clickOutsideMonitor: Any?
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
        setupPanel()
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

    private func setupPanel() {
        let view = SessionPanelView(
            sessionManager: sessionManager,
            discoveryManager: discoveryManager,
            workPatternStore: workPatternStore,
            stateMachine: stateMachine,
            onTakeBreak: { [weak self] in
                self?.reminderEngine.recordBreak()
                self?.workPatternStore.recordBreakTaken()
                self?.hidePanel()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "PixelPal"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: view)
        panelWindow = panel
    }

    private func setupFloatingCharacter() {
        floatingCharacter.setup()
        floatingCharacter.onClick = { [weak self] in
            self?.floatingCharacterClicked()
        }
        // Initial animation
        let charId = discoveryManager.activeCharacter.id
        floatingCharacter.updateAnimation(characterId: charId, state: .idle)
    }

    @objc private func statusItemClicked() {
        if panelVisible {
            hidePanel()
        } else {
            // Position below menu bar button
            if let button = statusItem.button, let buttonWindow = button.window {
                let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
                showPanel(near: NSPoint(x: buttonFrame.midX - 150, y: buttonFrame.minY - 430))
            }
        }
    }

    private func floatingCharacterClicked() {
        if panelVisible {
            hidePanel()
        } else if let floatingView = floatingCharacter.anchorView, let window = floatingView.window {
            // Position above the floating character
            let charFrame = window.frame
            showPanel(near: NSPoint(x: charFrame.midX - 150, y: charFrame.maxY + 8))
        } else {
            statusItemClicked()
        }
    }

    private func showPanel(near point: NSPoint) {
        guard let panel = panelWindow, let screen = NSScreen.main else { return }

        // Clamp to screen bounds
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = max(visibleFrame.minX + 8, min(point.x, visibleFrame.maxX - panelSize.width - 8))
        let y = max(visibleFrame.minY + 8, min(point.y, visibleFrame.maxY - panelSize.height - 8))

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
        panelVisible = true

        // Click-outside-to-close monitor
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        panelWindow?.orderOut(nil)
        panelVisible = false
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
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
        stateMachine.activeCharacterId = characterId

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
        if let reminder = reminderEngine.currentReminder, !stateMachine.showBubble {
            let charId = discoveryManager.activeCharacter.id
            // Use character-specific speech if available
            let context: SpeechPool.Context = switch reminder.layer {
            case 1: .nudgeEye
            case 2: .nudgeMicro
            default: .nudgeDeep
            }
            let text = SpeechPool.line(character: charId, context: context) ?? reminder.message
            stateMachine.showReminderBubble(text)
            workPatternStore.recordReminderSuggested()
        }
    }

    private func handleDiscovery() {
        if let newCharId = discoveryManager.consumePendingDiscovery() {
            if let profile = discoveryManager.profile(for: newCharId) {
                let greeting = SpeechPool.line(character: newCharId, context: .greeting) ?? profile.greeting
                stateMachine.state = .celebrate
                stateMachine.showDiscoveryBubble(greeting, characterName: profile.name)
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
