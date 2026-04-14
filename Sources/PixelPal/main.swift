import AppKit
import SwiftUI
import PixelPalCore

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
    private let evolutionEngine = EvolutionEngine()
    private let workContext: WorkContext
    private let speechEngine: SpeechEngine
    private let notificationRouter = NotificationRouter()
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
         reminderEngine: ReminderEngine,
         workContext: WorkContext) {
        self.stateMachine = stateMachine
        self.sessionManager = sessionManager
        self.discoveryManager = discoveryManager
        self.workPatternStore = workPatternStore
        self.reminderEngine = reminderEngine
        self.workContext = workContext
        self.speechEngine = SpeechEngine(workContext: workContext, reminderEngine: reminderEngine)
        super.init()
        reconfigureNtfySink()
        setupStatusItem()
        setupPanel()
        setupFloatingCharacter()
        observeState()
    }

    /// Read ntfy settings from UserDefaults and rebuild the sink list.
    /// Called on startup and whenever the user toggles the setting in UI.
    func reconfigureNtfySink() {
        notificationRouter.removeAllSinks()
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "pixelpal_ntfy_enabled"),
              let topic = defaults.string(forKey: "pixelpal_ntfy_topic"),
              !topic.isEmpty else {
            return
        }
        let server = defaults.string(forKey: "pixelpal_ntfy_server") ?? "https://ntfy.sh"
        notificationRouter.addSink(NtfyRemoteSink(topic: topic, server: server))
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
            workContext: workContext,
            stateMachine: stateMachine,
            onToggleMinimal: { [weak self] minimal in
                self?.floatingCharacter.setMinimalMode(minimal)
            },
            onUninstall: { [weak self] in
                let configurator = AutoConfigurator()
                configurator.unconfigure()
                self?.hidePanel()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onReconfigureNtfy: { [weak self] in
                self?.reconfigureNtfySink()
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
        // Restore Minimal Mode preference
        if UserDefaults.standard.bool(forKey: "pixelpal_minimal_mode") {
            floatingCharacter.setMinimalMode(true)
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
        // Fast loop for animation state (0.3s)
        stateObserver = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.switchAnimation(to: self.stateMachine.state)
                self.handleBubble()
                self.handleDiscovery()
                self.handleEvolution()
            }
        }
        // Slower loop for speech evaluation (5s) — SpeechEngine decides when to speak
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.workContext.resetIfNewDay()
                self.evaluateSpeech()
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

        // Determine evolution stage for active character
        let evolutionDays = discoveryManager.discovered
            .first(where: { $0.characterId == characterId })?.evolutionDays ?? 0
        let evoStage = EvolutionStage.from(days: evolutionDays)

        // Update floating character too
        floatingCharacter.updateAnimation(characterId: characterId, state: state, evolution: evoStage)

        let interval: TimeInterval
        switch state {
        case .idle:
            currentFrames = SpriteSheet.frames(character: characterId, state: "idle", evolution: evoStage)
            interval = 0.8
        case .working:
            currentFrames = SpriteSheet.frames(character: characterId, state: "working", evolution: evoStage)
            interval = 0.2
        case .celebrate:
            currentFrames = SpriteSheet.frames(character: characterId, state: "celebrate", evolution: evoStage)
            interval = 0.15
        case .nudge:
            currentFrames = SpriteSheet.frames(character: characterId, state: "nudge", evolution: evoStage)
            interval = 0.6
        case .comfort:
            currentFrames = SpriteSheet.frames(character: characterId, state: "idle", evolution: evoStage)
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
            let avatar = SpriteSheet.avatar(character: char.id, size: 32)
            bubbleController.show(text: stateMachine.bubbleText, avatar: avatar, characterName: char.name) { [weak self] in
                self?.speechEngine.userDismissed()
                self?.stateMachine.userDismissedBubble()
                self?.isBubbleShowing = false
                self?.bubbleController.dismiss()
            }
        } else if !stateMachine.showBubble && isBubbleShowing {
            isBubbleShowing = false
            bubbleController.dismiss()
        }
    }

    // MARK: - SpeechEngine evaluation (replaces timer-based reminders)

    private func evaluateSpeech() {
        guard !stateMachine.showBubble else { return }
        let charId = discoveryManager.activeCharacter.id

        if let (trigger, text) = speechEngine.evaluate(characterId: charId, currentState: stateMachine.state) {
            // Set appropriate animation state based on trigger
            switch trigger {
            case .nudgeEye, .nudgeMicro, .nudgeDeep, .lateNight:
                stateMachine.state = .nudge
                workPatternStore.recordReminderSuggested()
            case .errorStreak:
                stateMachine.state = .comfort
            case .taskComplete, .milestone, .flowExit:
                stateMachine.state = .celebrate
            case .flowEntry, .returnFromAbsence, .branchSwitch, .claudeNeedsYou:
                break // keep current state
            }
            stateMachine.showReminderBubble(text)

            // Fan out to any remote sinks (ntfy etc.). Router silently drops
            // triggers that don't warrant a push — rest reminders stay local.
            notificationRouter.route(
                trigger: trigger,
                text: text,
                characterId: charId,
                characterName: discoveryManager.activeCharacter.name
            )
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

    private func handleEvolution() {
        let charId = discoveryManager.activeCharacter.id
        guard let discovery = discoveryManager.discovered.first(where: { $0.characterId == charId }) else { return }

        if let newStage = evolutionEngine.checkMilestone(characterId: charId, evolutionDays: discovery.evolutionDays) {
            // Show evolution speech bubble
            let text = SpeechPool.line(character: charId, context: .evolution(newStage.dayThreshold))
                ?? "Day \(newStage.dayThreshold). Something feels different."
            stateMachine.state = .celebrate
            stateMachine.showDiscoveryBubble(text, characterName: discoveryManager.activeCharacter.name)
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
    private var workContext: WorkContext?
    private var discoveryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sm = StateMachine()
        let sessions = SessionManager()
        let discovery = DiscoveryManager()
        let patterns = WorkPatternStore()
        let reminders = ReminderEngine()
        let ctx = WorkContext()

        stateMachine = sm
        sessionManager = sessions
        discoveryManager = discovery
        workPatternStore = patterns
        reminderEngine = reminders
        workContext = ctx

        // Wire WorkContext into StateMachine
        sm.workContext = ctx

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
                    break // handled by state machine + speech engine
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
            reminderEngine: reminders,
            workContext: ctx
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

        // First-launch hint: remind user to open a new terminal
        showShellHookHintIfNeeded(sm: sm, charId: discovery.activeCharacter.id)
    }

    /// Show a one-time hint to open a new terminal so shell hooks activate.
    /// Only shows if no shell events received within 10 seconds of launch.
    private func showShellHookHintIfNeeded(sm: StateMachine, charId: String) {
        let hintKey = "pixelpal_shell_hint_shown"
        // Only show once per install
        guard !UserDefaults.standard.bool(forKey: hintKey) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let ctx = self?.workContext else { return }
            // If no activity detected, the hook isn't loaded
            if ctx.commandVelocity == 0 && ctx.todayCommits == 0 {
                let isCN = SpeechPool.isChinese
                let text = isCN
                    ? "打开一个新的终端窗口，我就能感知你的工作状态了。"
                    : "Open a new terminal window so I can track your work."
                sm.showReminderBubble(text)
                UserDefaults.standard.set(true, forKey: hintKey)
            }
        }
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
