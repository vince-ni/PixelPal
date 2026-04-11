import AppKit
import SwiftUI

/// Floating pixel character in screen corner — the primary visual presence.
/// Click → expand session panel. Hover → 20% transparent + click-through.
/// Full-screen app → auto-hide (menu bar icon takes over).
@MainActor
final class FloatingCharacterController {
    private var window: NSPanel?
    private var spriteView: NSImageView?
    private var animationTimer: Timer?
    private var currentFrames: [NSImage] = []
    private var frameIndex = 0
    private var isMinimalMode = false
    private var trackingArea: NSTrackingArea?

    var onClick: (() -> Void)?

    // MARK: - Setup

    func setup() {
        let size = NSSize(width: 48, height: 48) // larger than menu bar for corner presence

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.imageScaling = .scaleProportionallyUpOrDown

        // Click handler
        let clickView = ClickableView(frame: NSRect(origin: .zero, size: size))
        clickView.onClick = { [weak self] in self?.onClick?() }
        clickView.addSubview(imageView)
        panel.contentView = clickView

        // Hover tracking for transparency
        let area = NSTrackingArea(
            rect: NSRect(origin: .zero, size: size),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: clickView,
            userInfo: nil
        )
        clickView.addTrackingArea(area)
        clickView.onMouseEntered = { [weak panel] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel?.animator().alphaValue = 0.2
            }
        }
        clickView.onMouseExited = { [weak panel] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel?.animator().alphaValue = 1.0
            }
        }

        // Position: bottom-right corner
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - size.width - 20
            let y = visibleFrame.minY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = panel
        self.spriteView = imageView
        self.trackingArea = area

        if !isMinimalMode {
            panel.orderFront(nil)
        }
    }

    // MARK: - Animation

    func updateAnimation(characterId: String, state: CharacterState) {
        let stateStr = state.rawValue
        let newFrames = SpriteSheet.frames(character: characterId, state: stateStr)

        // For the floating window, use larger sprites if available
        let largeFrames: [NSImage]
        if stateStr == "idle" {
            // Try to load the large sprite for idle
            let largePath = ((ProcessInfo.processInfo.environment["HOME"] ?? "") as NSString)
                .appendingPathComponent("Projects/PixelPal/Assets/spike_large.png")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: largePath)),
               let img = NSImage(data: data) {
                let scaled = scaleForFloating(img)
                largeFrames = [scaled]
            } else {
                largeFrames = newFrames.map { scaleForFloating($0) }
            }
        } else {
            largeFrames = newFrames.map { scaleForFloating($0) }
        }

        currentFrames = largeFrames
        frameIndex = 0

        let interval: TimeInterval
        switch state {
        case .idle: interval = 0.8
        case .working: interval = 0.2
        case .celebrate: interval = 0.15
        case .nudge: interval = 0.6
        case .comfort: interval = 1.0
        }

        animationTimer?.invalidate()
        updateFrame()
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateFrame() }
        }
    }

    private func updateFrame() {
        guard !currentFrames.isEmpty else { return }
        spriteView?.image = currentFrames[frameIndex % currentFrames.count]
        frameIndex += 1
    }

    private func scaleForFloating(_ source: NSImage) -> NSImage {
        let targetSize = NSSize(width: 48, height: 48)
        let output = NSImage(size: targetSize)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none // pixel crisp
        source.draw(in: NSRect(origin: .zero, size: targetSize))
        output.unlockFocus()
        return output
    }

    // MARK: - Minimal Mode

    func setMinimalMode(_ minimal: Bool) {
        isMinimalMode = minimal
        if minimal {
            window?.orderOut(nil)
        } else {
            window?.orderFront(nil)
        }
    }

    // MARK: - Full screen detection

    func handleFullScreenChange(isFullScreen: Bool) {
        if isFullScreen || isMinimalMode {
            window?.orderOut(nil)
        } else {
            window?.orderFront(nil)
        }
    }
}

// MARK: - Clickable view with hover support

private class ClickableView: NSView {
    var onClick: (() -> Void)?
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
