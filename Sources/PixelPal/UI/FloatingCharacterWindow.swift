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

    /// The content view of the floating window, used as popover anchor
    var anchorView: NSView? { window?.contentView }

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

        // Restore saved position or default to bottom-right corner
        let savedX = UserDefaults.standard.double(forKey: "pixelpal_float_x")
        let savedY = UserDefaults.standard.double(forKey: "pixelpal_float_y")
        if savedX != 0 || savedY != 0 {
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else if let screen = NSScreen.main {
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
        if stateStr == "idle", let img = loadLargeSprite(characterId) {
            largeFrames = [scaleForFloating(img)]
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
        // Only animate if there are multiple frames — single frame doesn't need a timer
        if currentFrames.count > 1 {
            animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateFrame() }
            }
        }
    }

    private func updateFrame() {
        guard !currentFrames.isEmpty else { return }
        spriteView?.image = currentFrames[frameIndex % currentFrames.count]
        frameIndex += 1
    }

    private func loadLargeSprite(_ characterId: String) -> NSImage? {
        let name = "\(characterId)_large.png"
        let dirs = [
            (Bundle.main.resourcePath ?? "") + "/Assets",
            ((ProcessInfo.processInfo.environment["HOME"] ?? "") as NSString).appendingPathComponent("Projects/PixelPal/Assets")
        ]
        for dir in dirs {
            let path = (dir as NSString).appendingPathComponent(name)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let img = NSImage(data: data) {
                return img
            }
        }
        return nil
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

    private var isDragging = false
    private var dragStartPoint: NSPoint = .zero
    private let dragThreshold: CGFloat = 4.0

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStartPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let currentPoint = event.locationInWindow
        let distance = hypot(currentPoint.x - dragStartPoint.x, currentPoint.y - dragStartPoint.y)
        if distance > dragThreshold {
            isDragging = true
        }
        if isDragging, let window = self.window {
            var origin = window.frame.origin
            origin.x += event.deltaX
            origin.y -= event.deltaY
            window.setFrameOrigin(origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            onClick?()
        } else {
            // Save position after drag
            if let origin = self.window?.frame.origin {
                UserDefaults.standard.set(origin.x, forKey: "pixelpal_float_x")
                UserDefaults.standard.set(origin.y, forKey: "pixelpal_float_y")
            }
        }
        isDragging = false
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
