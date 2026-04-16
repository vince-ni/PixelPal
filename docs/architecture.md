# PixelPal — Architecture

A headless core, a presentation shell, and a protocol surface for every way the outside world gets into or out of the system. Nothing in the business layer imports AppKit.

## The single most important decision

PixelPal is a macOS menu-bar app today. The business logic is not a macOS menu-bar app. The library compiles cleanly against Foundation alone. Tomorrow it can ship as a CLI, an iOS companion, a Team Plan server-side daemon, or embedded inside another editor — without touching a line of `PixelPalCore`.

This is not hypothetical future-proofing. It is the one structural rule that every other decision in the codebase inherits from. If a feature can't be written so that the core knows nothing about NSStatusBar, it is a UI feature and it lives in `Sources/PixelPal/`. If it can be written that way, it belongs in `Sources/PixelPalCore/` and it gets unit tests that run under `swift test` with no AppKit runtime.

This rule — library before app — is why the codebase moves fast. Every new capability lands first as a headless, testable primitive, then gets a thin presentation layer on top. The presentation layer is disposable. The primitive is the asset.

## Layout

```
Sources/
├── PixelPalCore/              — headless, UI-free, unit-testable
└── PixelPal/                  — AppKit shell, SwiftUI views, lifecycle

Backend/                       — Cloudflare Workers + D1 (~130 LOC TS)
Shell/                         — ~50-line zsh hook, shipped as resource
Scripts/                       — build + LaunchAgent install
Tests/PixelPalTests/           — 94 tests across 14 suites
docs/                          — architecture, design principles, ui journey
```

The `PixelPalCore` target exports 15 Swift files totaling roughly 3,100 lines of production code. The `PixelPal` target is the AppKit/SwiftUI shell, around 2,100 lines, most of it view code. The ratio is deliberate: the boring part is larger than the pretty part.

## System diagram

```
 ┌────────────────────────────────────────────────────────────┐
 │  Any terminal  (Ghostty, iTerm2, Warp, Terminal.app, cmux) │
 └───────────────────────┬────────────────────────────────────┘
                         │ shell hook (zsh, ~50 LOC)
                         ▼
 ┌──────────────┐        ┌────────────────────────────────┐
 │ Claude Code  │───────▶│    Unix domain socket          │
 │ Codex        │ hooks  │    (length-prefixed JSON)      │
 │ Aider        │        └───────────────┬────────────────┘
 └──────────────┘                        │ ProviderEvent
                                         ▼
                    ┌────────────────────────────────────┐
                    │           PixelPalCore             │
                    │                                    │
                    │   ProviderAdapter ×3               │
                    │          ↓                         │
                    │   SocketServer                     │
                    │          ↓                         │
                    │   StateMachine ←→ WorkContext      │
                    │          ↓                         │
                    │   SpeechEngine (context-aware)     │
                    │          ↓                         │
                    │   NotificationRouter               │
                    │     ├── local bubble               │
                    │     └── NtfyRemoteSink → phone     │
                    │                                    │
                    │   EvolutionEngine · DiscoveryManager·│
                    │   ReminderEngine · WorkPatternStore│
                    │   CloudSync (iCloud KV + D1)       │
                    └───────────────┬────────────────────┘
                                    │
                    ┌───────────────▼────────────────────┐
                    │            PixelPal                │
                    │    MenuBar · FloatingWindow        │
                    │    SpeechBubble · SessionPanel     │
                    │    AnimatedAvatarView              │
                    └────────────────────────────────────┘
```

Data flow is strictly one direction: terminal events push into the core, the core decides, the shell displays. The UI never polls, never inspects the file system, never cares about process state. If the shell crashed, the core would keep working silently; if the core crashed, the shell would freeze with the last known state. Isolation is value.

## Core abstractions

Six primitives. Anything more is over-design; anything less leaks responsibilities.

### 1. `ProviderAdapter` — pluggable AI tool integration

```swift
public protocol ProviderAdapter {
    var id: String { get }
    var displayName: String { get }
    var isInstalled: Bool { get }
    var supportsNativeRemote: Bool { get }
    func parseOutput(_ line: String) -> ProviderEvent?
}
```

The entire "which AI tool are we running" concern collapses into 20 lines of protocol. `ClaudeCodeAdapter`, `CodexAdapter`, and `AiderAdapter` each live in their own file. Adding a fourth is one new file and zero changes to any existing code.

**Why a protocol and not a switch statement.** Because a switch would have meant every UI site knows how to special-case each provider. The adapter pattern flattens the knowledge — each adapter is sealed inside its own file and the rest of the codebase treats them uniformly.

**What the protocol deliberately does not have.** No `buildProcess` or `spawn` method. PixelPal does not run the agents — the user runs them in their own terminal, and the shell hook + `parseOutput` surface what the app needs to know. An earlier version of the adapter carried a `buildProcess(workspace:remote:) -> Process` method; it was removed along with the whole spawn path once the observational model proved cleaner. Observe, never drive.

### 2. `SocketServer` + `ShellEvent` — the one ingress

Shell events enter through a single Unix domain socket with length-prefixed JSON messages. Malformed input, oversized payloads, injection attempts, concurrent writes — all covered by 8 red-team test cases that run on every build.

```swift
public struct ShellEvent {
    public enum Kind: String, Codable { case exec, prompt, claude_notify, claude_stop }
    public let kind: Kind
    public let timestamp: TimeInterval
    public let command: String?
    public let exitCode: Int?
    public let duration: Int?
    public let pwd: String?
    public let gitBranch: String?
}
```

**Why a socket and not kqueue, dtrace, or a file watcher.** Sockets are explicit. The shell decides what to send; the app decides what to consume. No privileged APIs, no Full Disk Access permission prompt, no accidental exfiltration surface. The shell hook script is 50 lines and human-readable. If you want to know what PixelPal sees, you read one file.

**Content that crosses the socket is only metadata.** Exit codes, durations, timestamps, branch names. The command itself is transmitted but never stored — it passes through the state machine for classification and is dropped. Work content (file contents, diffs, commit messages, agent prompts) never enters the socket. This constraint is what lets us tell a user with a straight face that their code never leaves the machine.

### 3. `WorkContext` — the observation snapshot

```swift
public final class WorkContext: ObservableObject {
    @Published public private(set) var currentBranch: String
    @Published public private(set) var branchMinutes: Int
    @Published public private(set) var minutesSinceBreak: Int
    @Published public private(set) var consecutiveErrors: Int
    @Published public private(set) var todayCommits: Int
    @Published public private(set) var todayErrors: Int
    @Published public private(set) var isFlowState: Bool
    @Published public private(set) var commandVelocity: Double
    // ...
}
```

Every speech decision, every notification, every visual state transition is a pure function of `WorkContext`. This is the design's central idea: the companion's behavior is not scripted, it is *observational*. The character doesn't run on timers; it runs on what the context says is true right now.

**Why one aggregate object instead of scattered counters.** Decisions want to be readable. "`Speak about a break if minutes_since_break > 52 and not is_flow_state`" is a sentence. It maps to one line of Swift against one object. If the counters lived in three different engines, decisions would have to plumb through three dependencies, and the meaning of "right now" would diverge across engines.

### 4. `SpeechEngine` — context-aware triggering

The version-one engine broadcasted on a timer. Every 15 minutes, pick a random line. Every user experienced it as a fortune cookie.

The current engine listens for observations crossing thresholds worth speaking about. A task just completed. An error streak just reached three. The user just came back from 30 minutes of flow. Each trigger has a real data point attached, and each line in `SpeechPool` is templated so that data can be substituted in — "You've been on `auth-refactor` for three days" is the same line as "You've been on `sql-debug` for 6 hours," with the engine filling in the blanks from `WorkContext`.

```swift
public enum Trigger {
    case taskComplete          // claude_stop or successful command
    case errorStreak           // consecutiveErrors >= threshold
    case nudgeEye              // 20 min without break + not in flow
    case nudgeMicro            // 52 min without break + not in flow
    case nudgeDeep             // 90 min without break (even in flow)
    case flowEntry / flowExit / returnFromAbsence
    case lateNight / branchSwitch / milestone / claudeNeedsYou
}
```

The gap between "random fortune cookie" and "a friend who notices" is the difference between scripted and observational. It is also the difference between PixelPal and every other desktop companion app in history.

**Cooldown and overload protection.** Minimum 30 seconds between any two utterances. Two dismissals in 5 minutes silences the engine for 1 hour. The product's first responsibility is not to become the thing it promised not to be.

### 5. `EvolutionEngine` — passive growth

```swift
public enum EvolutionStage: Int, Comparable {
    case newborn = 0     // Day 0-6
    case familiar = 1    // Day 7-13
    case settled = 2     // Day 14-29
    case bonded = 3      // Day 30-59
    case devoted = 4     // Day 60-89
    case eternal = 5     // Day 90+
}
```

Evolution is a pure function of cumulative companionship days. Not behavior. Not achievements. Not XP. `EvolutionStage.from(days: Int)` is a six-line switch with no side effects. It has 10 unit tests covering boundary days 6/7, 13/14, 29/30, 59/60, 89/90, and negative/zero/large inputs.

**Why a closed enum and not an open `EvolutionLevel: Int`.** Because extensibility is not a feature here; stability is. A user at day 89 should be able to think "one more day until `devoted`," and trust that no future release will renumber the threshold or insert a new stage between `settled` and `bonded`. Evolution is a promise, not a configuration knob.

**Why no speed-up.** Because paying to skip the days would make the relationship a transaction. The fact that `Day 30` cannot be bought is the relationship.

### 6. `NotificationSink` + `NotificationRouter` — pluggable effect surface

```swift
public protocol NotificationSink: Sendable {
    func deliver(_ notification: RemoteNotification) async
}

@MainActor
public final class NotificationRouter {
    public func route(trigger: SpeechEngine.Trigger,
                      text: String,
                      characterId: String,
                      characterName: String) { /* ... */ }

    public nonisolated static func kind(for trigger: SpeechEngine.Trigger)
        -> RemoteNotification.Kind? { /* ... */ }
}
```

The router encodes the one policy that matters: which triggers are worth pushing remotely, and which ones stay local. Task-complete, error-streak, and Claude-needs-input push to the phone. Rest reminders stay local — buzzing "take a break" on a phone when the user is already away from their desk is noise, not care. That decision lives in one pure function, `kind(for:)`, with eight test cases asserting it.

`NtfyRemoteSink` is the current implementation. Tomorrow: `SlackSink`, `DiscordSink`, `TelegramSink` — each a single file, each registered into a router that never has to change.

**Capability-based security.** The ntfy topic is the token. A 20-character random suffix generated in-app — `pixelpal-abc123xyz789ghi456mno` — unguessable without access to the topic name. No auth, no account, no server state to breach. The product is self-hostable for users who distrust the public ntfy.sh instance.

## Event flow end-to-end

```
1. User types `npm test` in terminal.
2. zsh hook fires, writes {"kind":"exec","ts":...,"cmd":"npm test"} to socket.
3. SocketServer receives, parses, emits ShellEvent.
4. StateMachine.handleEvent(event):
     — sets state = .working
     — records WorkContext.recordExec(command, timestamp)
5. WorkContext.commandVelocity increments.
6. SpeechEngine polls WorkContext on next tick.
     — Is consecutiveErrors ≥ 3? No.
     — Is flowEntry just crossed? No.
     — Is minutesSinceBreak > 52? No.
     — Return nil. (Silence is the default.)
7. [Eight minutes later] npm test fails.
8. prompt event arrives, exitCode != 0, duration 487.
9. StateMachine transitions → .comfort, schedules transition → .idle in 3s.
10. WorkContext.consecutiveErrors = 3.
11. SpeechEngine fires errorStreak trigger.
     — Picks a line from SpeechPool.line(character: "spike", context: .comfort)
     — Returns ("errorStreak", "Hey! It's just a bug! You'll squish it!!")
12. MenuBarController shows bubble.
13. NotificationRouter.route — maps errorStreak to .errorStreak kind.
14. NtfyRemoteSink.deliver — POST https://ntfy.sh/{topic} with
    Title: "Spike: Needs attention"
    Priority: 4
    Body: the speech line
15. User's phone (ntfy iOS app) receives push within 2 seconds.
```

Fifteen steps, zero scripted animations, zero hardcoded timers. Everything is an observation flowing through a decision graph.

## Security model

**No user content over the network.** Work data (file contents, diffs, agent prompts, command output beyond exit code) never crosses the socket boundary, never writes to disk outside the user's machine, never reaches any remote service. iCloud KV syncs character discovery state only — a list of 9 unlockable companion IDs and their cumulative day counts. D1 does the same as a backup. CloudSync holds no telemetry, no analytics, no user identification beyond an anonymous device UUID.

**Topic is the capability.** ntfy's trust model is "anyone who knows the topic can publish and subscribe." PixelPal generates unguessable topics (20 chars from a 32-char alphabet, ambiguous characters removed — 32²⁰ ≈ 10³⁰ possible). Leaking a topic leaks the ability to receive push notifications from one user's PixelPal; nothing else.

**Red-team coverage at every external boundary.** The socket server has 8 adversarial test cases: malformed JSON, oversized payloads, concurrent writes, injection attempts, boundary timestamps, null fields, UTF-8 edge cases, partial frames. The ntfy sink has separate tests for request construction that assert every header and body bit against the ntfy HTTP spec. If something listens on the world, it gets attacked in tests before it ships.

**Keychain for any persisted secret.** `CloudSync` uses `kSecClassGenericPassword` via `SecItemCopyMatching` — no plaintext credentials on disk, ever. Right now no user-visible secrets are stored; the infrastructure exists for the moment they are.

## Test philosophy

94 tests across 14 suites. Distributions:
- 10 evolution-engine boundary tests
- 8 provider-registry and parsing tests
- 8 speech-engine context-aware decision tests
- 8 speech-pool coverage + fallback tests
- 7 state-machine transition tests
- 7 discovery idempotency tests
- 6 work-context aggregation tests
- 16 notification router + ntfy request construction tests
- 3 accent color coverage + distinctness tests
- plus discovery manager, speech edge cases, state labels, stage labels

Tests describe behavior, never implementation. Renaming a private function never breaks a test. The product can be refactored end-to-end and the suite catches every regression that matters.

**Pure function extraction is the testability tax.** `NtfyRemoteSink.buildRequest(...)` is a pure function separate from `deliver(...)` — the async network call is untested, but the request's URL, headers, and body are asserted against real inputs without touching the network. `NotificationRouter.kind(for:)` is `nonisolated static` specifically so tests can call it without an actor context. Isolating purity from side effects pays for itself the first time a test run is sub-20-milliseconds.

## Technology choices

- **Swift 5.9** with strict concurrency warnings on. The `@MainActor` boundary is enforced; anything crossing it has explicit `async` or explicit isolation.
- **SwiftUI + AppKit hybrid**. AppKit for the parts macOS-specific (NSStatusItem, NSPanel, NSMenu, keyboard shortcuts, NSHostingView); SwiftUI for everything else. No pretense that this is a SwiftUI-only app — it's a 1:1 match of each framework to the surfaces where it excels.
- **swift-testing**, not XCTest. Test macros are ergonomic enough that the coverage grew naturally alongside the code; the old ceremony of `func test...() { XCTAssert(...) }` always costs a test.
- **Nearest-neighbor rendering**. `NSGraphicsContext.current?.imageInterpolation = .none` applied at every scaling step. Pixel art stays pixel art at 22px, 32px, 48px, and Retina-doubled 96px. No filters, no smoothing.
- **Cloudflare Workers + D1** on the backend. Anonymous device UUID, 3 endpoints, CORS-enabled, zero-auth. Total backend surface: 130 lines of TypeScript.
- **Unix domain socket** for IPC. Length-prefixed JSON frames. No ports exposed to the network, ever.

## Non-goals (where the design refuses to go)

Stated explicitly, because what the product refuses to do is more definitive than what it does.

- **PixelPal will not become a task manager.** The companion observes; it does not track todos, schedule work, or nag about unfinished items. `Things`, `OmniFocus`, `Linear` exist. PixelPal is not a seventh one of those.
- **PixelPal will not review your code.** Not now, not behind a Pro toggle, not "opt-in." The companion cares about the human. The agents care about the code. That separation is the product.
- **PixelPal will not gamify.** No XP, no streaks, no leaderboards, no "you're on a 14-day streak — don't break it!" push notifications. These are psychological debt, not features.
- **PixelPal will not punish absence.** Take a month off. Come back. The character is exactly as you left it, and will greet you warmly. Any implementation where absence loses progress is a pull request that gets closed with "not our product."
- **PixelPal will not cloud-first.** Work data stays on the device. The `CloudSync` layer exists for character discovery state and can be disabled entirely without losing local functionality. The product must degrade gracefully to zero network.
- **PixelPal will not run a store.** No gacha. No buy-the-next-character. No seasonal lootbox. No "unlock Dash for $2.99." Discovery is a function of the journey, not of the wallet.

These are not caveats. They are the shape of the product.

## Where this architecture takes us next

The library/shell split makes three future variants trivial to reach:

1. **iOS companion** — `PixelPalCore` compiles clean on iOS. A native iOS app consuming the same library gives the user a companion that lives on both their desktop and their phone, sharing character state via iCloud KV.

2. **Team Plan daemon** — Same library, headless CLI binary. Runs on a team's bastion or developer's dotfiles, aggregates anonymized `WorkContext` snapshots across team members, gives managers a burnout-risk signal without reading anyone's code.

3. **Third-party integrations** — `ProviderAdapter` accepts anything that emits JSON events and spawns a process. Adding support for Zed, Helix, VS Code's Copilot chat, or an in-house agent harness is one adapter file.

None of these requires rewriting anything. Each requires implementing one protocol.

---

*Written by [Vince Ni](https://github.com/vince-ni). Repo: [github.com/vince-ni/PixelPal](https://github.com/vince-ni/PixelPal). Companion reading: [design-principles.md](./design-principles.md), [ui-redesign-journey.md](./ui-redesign-journey.md).*
