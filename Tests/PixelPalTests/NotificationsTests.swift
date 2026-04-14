import Testing
import Foundation
@testable import PixelPalCore

// MARK: - Router kind mapping

@Suite("NotificationRouter trigger mapping")
struct RouterKindTests {

    @Test("Task complete triggers map to taskComplete kind")
    func taskCompleteMapping() {
        #expect(NotificationRouter.kind(for: .taskComplete) == .taskComplete)
        #expect(NotificationRouter.kind(for: .milestone) == .taskComplete)
    }

    @Test("Error streak maps to errorStreak kind")
    func errorStreakMapping() {
        #expect(NotificationRouter.kind(for: .errorStreak) == .errorStreak)
    }

    @Test("Claude notify maps to claudeNeedsYou kind")
    func claudeNeedsYouMapping() {
        #expect(NotificationRouter.kind(for: .claudeNeedsYou) == .claudeNeedsYou)
    }

    @Test("Rest reminders stay local (no push)")
    func restRemindersNoPush() {
        #expect(NotificationRouter.kind(for: .nudgeEye) == nil)
        #expect(NotificationRouter.kind(for: .nudgeMicro) == nil)
        #expect(NotificationRouter.kind(for: .nudgeDeep) == nil)
    }

    @Test("Flow transitions stay local (no push)")
    func flowTransitionsNoPush() {
        #expect(NotificationRouter.kind(for: .flowEntry) == nil)
        #expect(NotificationRouter.kind(for: .flowExit) == nil)
        #expect(NotificationRouter.kind(for: .returnFromAbsence) == nil)
    }

    @Test("Ambient context triggers stay local")
    func ambientTriggersNoPush() {
        #expect(NotificationRouter.kind(for: .lateNight) == nil)
        #expect(NotificationRouter.kind(for: .branchSwitch) == nil)
    }
}

// MARK: - ntfy request construction

@Suite("NtfyRemoteSink request construction")
struct NtfySinkTests {

    private func sample(kind: RemoteNotification.Kind = .taskComplete) -> RemoteNotification {
        RemoteNotification(
            kind: kind,
            characterId: "spike",
            characterName: "Spike",
            text: "You did it!"
        )
    }

    @Test("Request URL is server + topic")
    func urlConstruction() throws {
        let req = try #require(NtfyRemoteSink.buildRequest(
            topic: "pixelpal-abc123",
            server: "https://ntfy.sh",
            notification: sample()
        ))
        #expect(req.url?.absoluteString == "https://ntfy.sh/pixelpal-abc123")
        #expect(req.httpMethod == "POST")
    }

    @Test("Body carries the speech text as UTF-8")
    func bodyEncoding() throws {
        let req = try #require(NtfyRemoteSink.buildRequest(
            topic: "t",
            server: "https://ntfy.sh",
            notification: sample()
        ))
        let body = try #require(req.httpBody)
        #expect(String(data: body, encoding: .utf8) == "You did it!")
    }

    @Test("Empty topic yields nil (no attack on ntfy.sh root)")
    func emptyTopicRejected() {
        let req = NtfyRemoteSink.buildRequest(
            topic: "",
            server: "https://ntfy.sh",
            notification: sample()
        )
        #expect(req == nil)
    }

    @Test("Title combines character name and kind suffix")
    func titleHeader() throws {
        let req = try #require(NtfyRemoteSink.buildRequest(
            topic: "t",
            server: "https://ntfy.sh",
            notification: sample(kind: .claudeNeedsYou)
        ))
        #expect(req.value(forHTTPHeaderField: "Title") == "Spike: Claude needs you")
    }

    @Test("Priority rises with kind urgency")
    func priorityHeader() throws {
        let taskComplete = try #require(NtfyRemoteSink.buildRequest(
            topic: "t", server: "https://ntfy.sh",
            notification: sample(kind: .taskComplete)
        ))
        let errorStreak = try #require(NtfyRemoteSink.buildRequest(
            topic: "t", server: "https://ntfy.sh",
            notification: sample(kind: .errorStreak)
        ))
        let claudeNeedsYou = try #require(NtfyRemoteSink.buildRequest(
            topic: "t", server: "https://ntfy.sh",
            notification: sample(kind: .claudeNeedsYou)
        ))
        #expect(taskComplete.value(forHTTPHeaderField: "Priority") == "3")
        #expect(errorStreak.value(forHTTPHeaderField: "Priority") == "4")
        #expect(claudeNeedsYou.value(forHTTPHeaderField: "Priority") == "5")
    }

    @Test("Tag maps to an emoji ntfy recognizes")
    func tagsHeader() throws {
        let req = try #require(NtfyRemoteSink.buildRequest(
            topic: "t", server: "https://ntfy.sh",
            notification: sample(kind: .taskComplete)
        ))
        #expect(req.value(forHTTPHeaderField: "Tags") == "white_check_mark")
    }

    @Test("Custom server host is respected (self-hosting)")
    func customServer() throws {
        let req = try #require(NtfyRemoteSink.buildRequest(
            topic: "t",
            server: "https://ntfy.mydomain.dev",
            notification: sample()
        ))
        #expect(req.url?.host == "ntfy.mydomain.dev")
    }
}

// MARK: - Topic generator

@Suite("Topic generator")
struct TopicGeneratorTests {

    @Test("Generated topic has pixelpal prefix and is long enough to be unguessable")
    func formatAndLength() {
        let t = NtfyRemoteSink.generateTopic()
        #expect(t.hasPrefix("pixelpal-"))
        #expect(t.count >= 28) // "pixelpal-" + 20 random chars
    }

    @Test("Generated topics avoid ambiguous characters 0/o/1/l")
    func alphabetSafety() {
        let t = NtfyRemoteSink.generateTopic()
        let suffix = String(t.dropFirst("pixelpal-".count))
        #expect(!suffix.contains("0"))
        #expect(!suffix.contains("o"))
        #expect(!suffix.contains("1"))
        #expect(!suffix.contains("l"))
    }

    @Test("Two generated topics are different (entropy check)")
    func uniqueness() {
        let a = NtfyRemoteSink.generateTopic()
        let b = NtfyRemoteSink.generateTopic()
        #expect(a != b)
    }
}
