import Foundation

// MARK: - Remote Notification Event

/// A notification worth delivering beyond the local machine — to the user's
/// phone or other device when they are away from the Mac.
///
/// Most speech triggers stay local (rest reminders, flow transitions): the
/// user is not in front of the Mac, a "take a break" buzz is noise, not care.
/// Only events that signal something the user actually wants to know remotely
/// become RemoteNotification: a task completed, an error streak, Claude
/// needing input.
public struct RemoteNotification: Equatable {

    public enum Kind: Equatable {
        case taskComplete
        case errorStreak
        case claudeNeedsYou

        /// ntfy priority (1=min, 3=default, 5=urgent).
        /// Rest reminders never reach this layer, so we stay between 3-5.
        public var ntfyPriority: String {
            switch self {
            case .taskComplete: return "3"
            case .errorStreak: return "4"
            case .claudeNeedsYou: return "5"
            }
        }

        /// ntfy tag → emoji in the push UI.
        public var ntfyTags: String {
            switch self {
            case .taskComplete: return "white_check_mark"
            case .errorStreak: return "warning"
            case .claudeNeedsYou: return "bell"
            }
        }

        public var titleSuffix: String {
            switch self {
            case .taskComplete: return "Task done"
            case .errorStreak: return "Needs attention"
            case .claudeNeedsYou: return "Claude needs you"
            }
        }
    }

    public let kind: Kind
    public let characterId: String
    public let characterName: String
    public let text: String

    public init(kind: Kind, characterId: String, characterName: String, text: String) {
        self.kind = kind
        self.characterId = characterId
        self.characterName = characterName
        self.text = text
    }
}

// MARK: - Sink Protocol

/// Something that can deliver a RemoteNotification to a channel.
/// Implementations: NtfyRemoteSink today; future SlackSink / TelegramSink
/// are each one file and zero changes to the router.
public protocol NotificationSink: Sendable {
    func deliver(_ notification: RemoteNotification) async
}

// MARK: - ntfy Implementation

/// Delivers RemoteNotifications to an ntfy topic via HTTP POST.
///
/// Security model: the topic name is the capability. Anyone who knows the
/// topic can both publish to it and subscribe to it. The default generator
/// produces a 24-char base32-ish string — unguessable without the token.
///
/// No authentication beyond topic secrecy. No personal data is sent: only
/// the character name, speech line, and notification kind. Work content
/// (commands, file paths, diff content) never enters a notification.
public final class NtfyRemoteSink: NotificationSink {

    public let topic: String
    public let server: String

    public init(topic: String, server: String = "https://ntfy.sh") {
        self.topic = topic
        self.server = server
    }

    public func deliver(_ notification: RemoteNotification) async {
        guard let request = Self.buildRequest(topic: topic, server: server, notification: notification) else {
            return
        }
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Pure request construction. Extracted so tests can assert the wire
    /// format without mocking the network.
    public static func buildRequest(topic: String,
                                    server: String,
                                    notification: RemoteNotification) -> URLRequest? {
        guard !topic.isEmpty,
              let url = URL(string: "\(server)/\(topic)") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(title(for: notification), forHTTPHeaderField: "Title")
        req.setValue(notification.kind.ntfyPriority, forHTTPHeaderField: "Priority")
        req.setValue(notification.kind.ntfyTags, forHTTPHeaderField: "Tags")
        req.httpBody = notification.text.data(using: .utf8)
        return req
    }

    private static func title(for n: RemoteNotification) -> String {
        "\(n.characterName): \(n.kind.titleSuffix)"
    }

    /// Generate an unguessable topic name. Use this when the user first
    /// enables ntfy push so they never pick a weak topic by accident.
    public static func generateTopic(prefix: String = "pixelpal") -> String {
        let alphabet = Array("abcdefghijkmnpqrstuvwxyz23456789") // no 0/o/1/l ambiguity
        let suffix = (0..<20).map { _ in alphabet.randomElement()! }
        return "\(prefix)-\(String(suffix))"
    }
}

// MARK: - Router

/// Decides which SpeechEngine triggers are worth pushing remotely.
/// The router is the single place that encodes "local only vs remote worthy"
/// policy — adding a new sink never changes this decision.
@MainActor
public final class NotificationRouter {

    private var sinks: [NotificationSink] = []

    public init() {}

    public func addSink(_ sink: NotificationSink) {
        sinks.append(sink)
    }

    public func removeAllSinks() {
        sinks.removeAll()
    }

    public var sinkCount: Int { sinks.count }

    /// Called from the speech evaluation loop. Triggers that don't map to
    /// a remote kind are dropped silently — the local bubble already handles them.
    public func route(trigger: SpeechEngine.Trigger,
                      text: String,
                      characterId: String,
                      characterName: String) {
        guard let kind = Self.kind(for: trigger) else { return }
        let notification = RemoteNotification(
            kind: kind,
            characterId: characterId,
            characterName: characterName,
            text: text
        )
        let sinkList = sinks
        for sink in sinkList {
            Task.detached {
                await sink.deliver(notification)
            }
        }
    }

    /// Pure mapping from local speech trigger to remote notification kind.
    /// Rest reminders and flow transitions return nil — not worth a push.
    public nonisolated static func kind(for trigger: SpeechEngine.Trigger) -> RemoteNotification.Kind? {
        switch trigger {
        case .taskComplete, .milestone:
            return .taskComplete
        case .errorStreak:
            return .errorStreak
        case .claudeNeedsYou:
            return .claudeNeedsYou
        case .nudgeEye, .nudgeMicro, .nudgeDeep,
             .flowEntry, .flowExit, .returnFromAbsence,
             .lateNight, .branchSwitch:
            return nil
        }
    }
}
