import AppKit
import SwiftUI

// MARK: - Sprite rendering

struct SpriteSheet {
    // Loads sprites from Assets dir, falls back to SF Symbols
    // To use real sprites: place idle.gif, working.gif, celebrate.gif in Assets/

    private static let assetsDir: String = {
        // Check next to the binary first, then project dir
        let bundle = Bundle.main.resourcePath ?? ""
        let candidates = [
            (bundle as NSString).appendingPathComponent("Assets"),
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/Projects/PixelPal/Assets"
        ]
        for dir in candidates {
            if FileManager.default.fileExists(atPath: dir) { return dir }
        }
        return candidates.last!
    }()

    static func idleFrames() -> [NSImage] {
        if let frames = loadGifFrames("idle") { return frames }
        return sfSymbolFrames("🦔", variants: ["circle", "circle.fill", "circle"])
    }

    static func workingFrames() -> [NSImage] {
        if let frames = loadGifFrames("working") { return frames }
        return sfSymbolFrames("⚡", variants: ["bolt.fill", "bolt.circle.fill", "bolt.fill"])
    }

    static func celebrateFrames() -> [NSImage] {
        if let frames = loadGifFrames("celebrate") { return frames }
        return sfSymbolFrames("🎉", variants: ["star.fill", "sparkles", "star.circle.fill", "sparkles"])
    }

    static func nudgeFrames() -> [NSImage] {
        if let frames = loadGifFrames("nudge") { return frames }
        return sfSymbolFrames("☕", variants: ["cup.and.saucer.fill", "cup.and.saucer", "cup.and.saucer.fill"])
    }

    // Load frames from an animated GIF/WebP in Assets/
    private static func loadGifFrames(_ name: String) -> [NSImage]? {
        let extensions = ["gif", "webp", "png"]
        for ext in extensions {
            let path = (assetsDir as NSString).appendingPathComponent("\(name).\(ext)")
            guard FileManager.default.fileExists(atPath: path),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }

            if ext == "png" {
                // Single frame PNG — use as-is
                if let img = NSImage(data: data) {
                    return [menuBarIcon(from: img)]
                }
            }

            // Animated GIF: extract frames
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { continue }
            let count = CGImageSourceGetCount(source)
            if count == 0 { continue }

            var frames: [NSImage] = []
            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    frames.append(menuBarIcon(from: nsImage))
                }
            }
            if !frames.isEmpty { return frames }
        }
        return nil
    }

    // Scale a sprite to menu bar size with nearest-neighbor (pixel-crisp)
    private static func menuBarIcon(from source: NSImage) -> NSImage {
        let targetHeight: CGFloat = 22 // max menu bar height
        let scale = targetHeight / source.size.height
        let targetWidth = round(source.size.width * scale)
        let size = NSSize(width: targetWidth, height: targetHeight)

        let output = NSImage(size: size)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none // nearest neighbor
        source.draw(in: NSRect(origin: .zero, size: size))
        output.unlockFocus()
        output.isTemplate = false
        return output
    }

    // Fallback: SF Symbol based icons
    private static func sfSymbolFrames(_ emoji: String, variants: [String]) -> [NSImage] {
        return variants.map { name in
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                let configured = img.withSymbolConfiguration(config) ?? img
                configured.isTemplate = true
                return configured
            }
            // Fallback: render emoji as image
            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size)
            image.lockFocus()
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
            emoji.draw(at: NSPoint(x: 1, y: 1), withAttributes: attrs)
            image.unlockFocus()
            return image
        }
    }
}

// MARK: - Menu Bar Controller

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let stateMachine: StateMachine
    private var animationTimer: Timer?
    private var currentFrames: [NSImage] = []
    private var frameIndex = 0
    private var popover = NSPopover()
    private var bubbleWindow: NSWindow?

    init(stateMachine: StateMachine) {
        self.stateMachine = stateMachine
        super.init()
        setupStatusItem()
        setupPopover()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Start with idle animation
        switchAnimation(to: .idle)
    }

    private func setupPopover() {
        let view = StatusPopoverView(stateMachine: stateMachine) {
            self.popover.performClose(nil)
        }
        popover.contentViewController = NSHostingController(rootView: view)
        popover.behavior = .transient
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func observeState() {
        // Poll state changes (simple approach for MVP)
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let newState = self.stateMachine.state
                self.switchAnimation(to: newState)
                self.handleBubble()
            }
        }
    }

    private var lastAnimatedState: CharacterState?

    private func switchAnimation(to state: CharacterState) {
        guard state != lastAnimatedState else { return }
        lastAnimatedState = state

        animationTimer?.invalidate()

        let interval: TimeInterval
        switch state {
        case .idle:
            currentFrames = SpriteSheet.idleFrames()
            interval = 0.8
        case .working:
            currentFrames = SpriteSheet.workingFrames()
            interval = 0.2
        case .celebrate:
            currentFrames = SpriteSheet.celebrateFrames()
            interval = 0.15
        case .nudge:
            currentFrames = SpriteSheet.nudgeFrames()
            interval = 0.6
        case .comfort:
            currentFrames = SpriteSheet.idleFrames()
            interval = 1.0
        }

        frameIndex = 0
        updateFrame()

        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateFrame() }
        }
    }

    private func updateFrame() {
        guard !currentFrames.isEmpty else { return }
        statusItem.button?.image = currentFrames[frameIndex % currentFrames.count]
        frameIndex += 1
    }

    private func handleBubble() {
        if stateMachine.showBubble {
            showBubbleWindow(text: stateMachine.bubbleText)
        } else if let window = bubbleWindow, window.alphaValue > 0 {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }

    private func showBubbleWindow(text: String) {
        let bubbleWidth: CGFloat = 280
        let bubbleHeight: CGFloat = 72
        let margin: CGFloat = 20

        if bubbleWindow == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.hasShadow = true
            window.ignoresMouseEvents = false
            window.alphaValue = 0
            bubbleWindow = window
        }

        guard let window = bubbleWindow else { return }

        let stateEmoji: String
        switch stateMachine.state {
        case .celebrate: stateEmoji = "🎉"
        case .nudge: stateEmoji = "☕"
        case .comfort: stateEmoji = "💜"
        default: stateEmoji = "🦔"
        }

        let bubbleView = BubbleView(text: text, emoji: stateEmoji) { [weak self] in
            self?.dismissBubble()
        }
        window.contentView = NSHostingView(rootView: bubbleView)
        window.setContentSize(NSSize(width: bubbleWidth, height: bubbleHeight))

        // Position: bottom-right corner of screen, above dock
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - bubbleWidth - margin
            let y = visibleFrame.minY + margin
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Fade in
        window.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 1.0
        }
    }

    private func dismissBubble() {
        guard let window = bubbleWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
        stateMachine.userDismissedBubble()
    }
}

// MARK: - SwiftUI Views

struct BubbleView: View {
    let text: String
    let emoji: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text("Spike")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .frame(width: 280)
    }
}

struct StatusPopoverView: View {
    @ObservedObject var stateMachine: StateMachine
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PixelPal")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(stateMachine.state.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Work: \(stateMachine.workMinutes) min")
            }
            .font(.system(size: 12))

            if !stateMachine.gitBranch.isEmpty {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.secondary)
                    Text(stateMachine.gitBranch)
                }
                .font(.system(size: 12))
            }

            Divider()

            Button("I took a break") {
                stateMachine.userTookBreak()
            }
            .font(.system(size: 11))

            Button("Quit PixelPal") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 200)
    }

    private var stateColor: Color {
        switch stateMachine.state {
        case .idle: return .green
        case .working: return .blue
        case .celebrate: return .yellow
        case .nudge: return .orange
        case .comfort: return .purple
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var socketServer: SocketServer?
    private var stateMachine: StateMachine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sm = StateMachine()
        stateMachine = sm

        let server = SocketServer { event in
            Task { @MainActor in
                sm.handleEvent(event)
            }
        }
        server.start()
        socketServer = server

        menuBarController = MenuBarController(stateMachine: sm)

        print("[PixelPal] Running. Menu bar icon active.")
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
