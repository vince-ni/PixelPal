import AppKit
import SwiftUI

/// Speech bubble that appears at the bottom-right corner of the screen.
/// Fade in 300ms / hold / fade out 300ms.
/// Not attached to the menu bar — near the terminal where the user is looking.
@MainActor
final class BubbleWindowController {
    private var window: NSPanel?

    func show(text: String, emoji: String, characterName: String, onDismiss: @escaping () -> Void) {
        let bubbleWidth: CGFloat = 280
        let bubbleHeight: CGFloat = 72
        let margin: CGFloat = 20

        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
            panel.hasShadow = true
            panel.alphaValue = 0
            window = panel
        }

        guard let window else { return }

        let bubbleView = BubbleView(text: text, emoji: emoji, characterName: characterName) {
            onDismiss()
        }
        window.contentView = NSHostingView(rootView: bubbleView)
        window.setContentSize(NSSize(width: bubbleWidth, height: bubbleHeight))

        // Position: bottom-right corner, above dock
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

    func dismiss() {
        guard let window, window.alphaValue > 0 else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.window?.orderOut(nil)
            }
        })
    }
}

struct BubbleView: View {
    let text: String
    let emoji: String
    let characterName: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(characterName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .frame(width: 280)
        .onTapGesture { onDismiss() } // tap anywhere on bubble to dismiss
    }
}
