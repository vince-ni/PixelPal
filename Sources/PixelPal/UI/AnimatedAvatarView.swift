import SwiftUI
import AppKit
import PixelPalCore

/// SwiftUI view that renders an animated pixel avatar for a given character
/// and state. Used by the panel header so the character in the header is
/// clearly alive — breathing in idle, jumping on celebrate — rather than
/// a static passport photo while the floating corner copy is animated.
///
/// Frame rate matches FloatingCharacterController (idle 0.8s, working 0.2s,
/// celebrate 0.15s, nudge 0.6s, comfort 1.0s). Nearest-neighbor scaling
/// preserves pixel crispness at any display size.
@MainActor
struct AnimatedAvatarView: View {
    let characterId: String
    let state: CharacterState
    let evolution: EvolutionStage
    let size: CGFloat

    @State private var frames: [NSImage] = []
    @State private var frameIndex = 0
    @State private var timer: Timer?

    var body: some View {
        Group {
            if let frame = currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundColor(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .onAppear { reload() }
        .onChange(of: characterId) { _, _ in reload() }
        .onChange(of: state) { _, _ in reload() }
        .onChange(of: evolution) { _, _ in reload() }
        .onDisappear { stopTimer() }
    }

    private var currentFrame: NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[frameIndex % frames.count]
    }

    private func reload() {
        stopTimer()
        frames = SpriteSheet.frames(character: characterId,
                                    state: state.rawValue,
                                    evolution: evolution)
        frameIndex = 0
        guard frames.count > 1 else { return }
        let interval = intervalFor(state)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in frameIndex &+= 1 }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func intervalFor(_ state: CharacterState) -> TimeInterval {
        switch state {
        case .idle:      return 0.8
        case .working:   return 0.2
        case .celebrate: return 0.15
        case .nudge:     return 0.6
        case .comfort:   return 1.0
        }
    }
}
