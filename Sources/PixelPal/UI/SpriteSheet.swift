import AppKit
import PixelPalCore

/// Loads character sprites from Assets directory or falls back to SF Symbols.
/// Supports: PNG (static), GIF/WebP (animated, frame extraction).
/// All scaling uses nearest-neighbor interpolation for pixel-crisp rendering.
struct SpriteSheet {

    private static let assetsDir: String = {
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

    /// Load frames for a specific character and state, with optional evolution variant.
    /// Priority: {char}_{state}_{evo} → {char}_{state} → {state} → SF Symbol
    /// For idle state: additional fallback to base character sprite
    static func frames(character: String, state: String, evolution: EvolutionStage = .newborn) -> [NSImage] {
        // Try evolution-specific asset first (e.g. spike_idle_evo2.gif)
        if let suffix = evolution.spriteSuffix {
            if let frames = loadFrames("\(character)_\(state)_\(suffix)"), !frames.isEmpty {
                return frames
            }
        }

        // Try character-specific state asset
        if let frames = loadFrames("\(character)_\(state)"), !frames.isEmpty {
            return frames
        }

        // Try generic state asset
        if let frames = loadFrames(state), !frames.isEmpty {
            return frames
        }

        // For idle state only: fall back to base character sprite
        if state == "idle" {
            if let frames = loadFrames("\(character)_idle"), !frames.isEmpty { return frames }
            if let frames = loadFrames("idle"), !frames.isEmpty { return frames }
            if let frames = loadFrames(character), !frames.isEmpty { return frames }
        }

        // Non-idle states: use SF Symbol (visually distinct from idle hedgehog)
        return sfSymbolFallback(for: state)
    }

    private static func loadFrames(_ name: String) -> [NSImage]? {
        for ext in ["gif", "webp", "png"] {
            let path = (assetsDir as NSString).appendingPathComponent("\(name).\(ext)")
            guard FileManager.default.fileExists(atPath: path),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }

            if ext == "png" {
                if let img = NSImage(data: data) {
                    return [menuBarIcon(from: img)]
                }
                continue
            }

            // Animated GIF/WebP: extract individual frames
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

    /// Load a character avatar at a specified size for in-panel display.
    /// Tries the HD sprite ({char}_large.png) first — falls back to the
    /// scaled menu-bar idle frame. Always nearest-neighbor for pixel crispness.
    static func avatar(character: String, size: CGFloat = 32) -> NSImage? {
        let largePath = (assetsDir as NSString).appendingPathComponent("\(character)_large.png")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: largePath)),
           let source = NSImage(data: data) {
            return scaledAvatar(from: source, size: size)
        }
        if let first = frames(character: character, state: "idle").first {
            return scaledAvatar(from: first, size: size)
        }
        return nil
    }

    private static func scaledAvatar(from source: NSImage, size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let output = NSImage(size: target)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        source.draw(in: NSRect(origin: .zero, size: target))
        output.unlockFocus()
        output.isTemplate = false
        return output
    }

    /// Black silhouette of the character sprite — used in Companion Log for
    /// undiscovered characters. Preserves the sprite's alpha shape so each
    /// character still has a distinct silhouette; paints the opaque pixels
    /// in a translucent label color (adapts to light/dark mode).
    static func silhouette(character: String, size: CGFloat = 28) -> NSImage? {
        guard let avatar = avatar(character: character, size: size) else { return nil }
        let output = NSImage(size: avatar.size)
        output.lockFocus()
        defer { output.unlockFocus() }
        NSGraphicsContext.current?.imageInterpolation = .none
        // Lay down the avatar so its alpha mask exists in the canvas.
        avatar.draw(in: NSRect(origin: .zero, size: avatar.size))
        // Paint solid color over the alpha mask only (source-atop composite).
        NSColor.labelColor.withAlphaComponent(0.35).setFill()
        NSRect(origin: .zero, size: avatar.size).fill(using: .sourceAtop)
        return output
    }

    /// Scale sprite to menu bar height with nearest-neighbor (pixel-crisp on Retina).
    static func menuBarIcon(from source: NSImage) -> NSImage {
        let targetHeight: CGFloat = 22
        let scale = targetHeight / max(source.size.height, 1)
        let targetWidth = round(source.size.width * scale)
        let size = NSSize(width: targetWidth, height: targetHeight)

        let output = NSImage(size: size)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        source.draw(in: NSRect(origin: .zero, size: size))
        output.unlockFocus()
        output.isTemplate = false
        return output
    }

    private static func sfSymbolFallback(for state: String) -> [NSImage] {
        let symbolNames: [String]
        switch state {
        case "working": symbolNames = ["bolt.fill", "bolt.circle.fill", "bolt.fill"]
        case "celebrate": symbolNames = ["star.fill", "sparkles", "star.circle.fill", "sparkles"]
        case "nudge": symbolNames = ["cup.and.saucer.fill", "cup.and.saucer", "cup.and.saucer.fill"]
        case "comfort": symbolNames = ["heart.fill", "heart", "heart.fill"]
        case "sleep": symbolNames = ["moon.fill", "moon.zzz.fill", "moon.fill"]
        default: symbolNames = ["circle.fill", "circle", "circle.fill"]
        }

        return symbolNames.compactMap { name in
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
            let configured = img.withSymbolConfiguration(config) ?? img
            configured.isTemplate = true
            return configured
        }
    }
}
