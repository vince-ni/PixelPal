import AppKit

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

    /// Load frames for a specific character and state.
    /// Naming convention: {characterId}_{state}.gif or {characterId}_{state}.png
    /// Falls back to: {state}.gif → {state}.png → idle.png → SF Symbol
    static func frames(character: String, state: String) -> [NSImage] {
        let searchNames = [
            "\(character)_\(state)",
            state,
            "\(character)_idle",
            "idle"
        ]

        for name in searchNames {
            if let frames = loadFrames(name), !frames.isEmpty {
                return frames
            }
        }

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
