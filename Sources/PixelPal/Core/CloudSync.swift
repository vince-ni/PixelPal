import Foundation

/// Three-layer persistence for character discovery data:
/// L1: Local JSON (always available, primary read source)
/// L2: iCloud KV (NSUbiquitousKeyValueStore, Apple-managed, requires entitlement)
/// L3: Cloudflare D1 (backup + future B2B, requires network)
///
/// Write: L1 + L2 + L3 simultaneously
/// Read: L1 first, L2 if L1 missing, L3 if L2 missing
@MainActor
final class CloudSync {

    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let iCloudKey = "pixelpal_discoveries"
    private let d1BaseURL: String
    private var deviceId: String

    init() {
        // D1 backend URL (empty = disabled until deployed)
        d1BaseURL = ProcessInfo.processInfo.environment["PIXELPAL_API_URL"]
            ?? "https://pixelpal-api.your-subdomain.workers.dev"

        // Device ID from Keychain or generate new
        deviceId = Self.loadDeviceId() ?? Self.generateDeviceId()
    }

    // MARK: - Sync discoveries to all layers

    func syncDiscoveries(_ discoveries: [DiscoveredCharacter]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(discoveries) else { return }

        // L2: iCloud KV (fire-and-forget, Apple handles sync)
        iCloudStore.set(data, forKey: iCloudKey)
        iCloudStore.synchronize()

        // L3: Cloudflare D1 (async, non-blocking)
        Task.detached { [weak self] in
            await self?.syncToD1(data)
        }
    }

    // MARK: - Restore from cloud (when local data is missing)

    func restoreDiscoveries() -> [DiscoveredCharacter]? {
        // Try L2: iCloud
        if let data = iCloudStore.data(forKey: iCloudKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let discoveries = try? decoder.decode([DiscoveredCharacter].self, from: data) {
                print("[PixelPal] Restored \(discoveries.count) discoveries from iCloud")
                return discoveries
            }
        }

        // Try L3: D1 (synchronous for restore — happens once on first launch)
        // This is intentionally blocking because it only runs when local + iCloud are both empty
        return nil // D1 restore is async, handled separately
    }

    func restoreFromD1() async -> [DiscoveredCharacter]? {
        guard let url = URL(string: "\(d1BaseURL)/api/sync?device_id=\(deviceId)") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let wrapper = try decoder.decode(SyncResponse.self, from: data)
            print("[PixelPal] Restored \(wrapper.characters.count) discoveries from D1")
            return wrapper.characters
        } catch {
            print("[PixelPal] D1 restore failed: \(error)")
            return nil
        }
    }

    // MARK: - iCloud change notification

    func startObserving(onChange: @escaping ([DiscoveredCharacter]) -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let data = self.iCloudStore.data(forKey: self.iCloudKey) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let discoveries = try? decoder.decode([DiscoveredCharacter].self, from: data) {
                    onChange(discoveries)
                }
            }
        }
    }

    // MARK: - D1 sync

    private func syncToD1(_ data: Data) async {
        guard let url = URL(string: "\(d1BaseURL)/api/sync") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "characters": String(data: data, encoding: .utf8) ?? "[]"
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[PixelPal] Synced to D1")
            }
        } catch {
            // Silent failure — D1 is backup, not critical
        }
    }

    // MARK: - Device ID

    private static func loadDeviceId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pixelpal.app",
            kSecAttrAccount as String: "device_id",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func generateDeviceId() -> String {
        let id = UUID().uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pixelpal.app",
            kSecAttrAccount as String: "device_id",
            kSecValueData as String: id.data(using: .utf8)!
        ]
        SecItemAdd(query as CFDictionary, nil)
        return id
    }
}

// MARK: - D1 API response model

private struct SyncResponse: Codable {
    let characters: [DiscoveredCharacter]
}
