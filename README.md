# PixelPal

**The only AI agent companion that cares about you, not just your code.**

PixelPal is a macOS companion app for developers who spend their days with Claude Code, Codex, and Aider. A pixel character lives in your screen corner, managing your AI sessions while quietly watching how you work — reminding you to rest, celebrating what you ship, and slowly growing with you over the months you spend together.

Most AI developer tooling optimizes what the agent can do. PixelPal optimizes what happens to the human using it.

---

## Why this exists

Every week another tool lands that makes AI coding more capable. Conductor manages diffs. Vibe Island owns the notch. Jean orchestrates multi-tool workflows. They all answer the same question: _how do we make the agent do more?_

Nobody is asking a different question: **the developer running three Claude Code sessions at 1 AM — are they okay?**

- Their last break was four hours ago.
- Their agent just errored out for the fifth time in a row.
- They have no idea which of their three terminals actually needs them.
- There is nothing in their environment that will ever gently say _"it can wait until tomorrow."_

Productivity tools treat humans like machines that happen to get tired. PixelPal treats the tired human as the actual product surface.

---

## What's built

**Phase 1 — the shell** (shipped, `v0.1`)

- Menu bar presence + draggable floating pixel character (`NSPanel`, pixel-crisp rendering)
- Session Manager for Claude Code: spawn, monitor, auto-restart on crash, stop
- Shell hook (zsh, ~50 lines) + Claude Code hooks, auto-injected on first launch — zero manual config
- Three-layer scientific break reminder engine (20-min eye rest / 52-min micro break / 90-min deep rest), gradual unlock over the first week
- Speech bubble with overload protection (2 dismissals in 5 min → silent for 1 hr)
- 9-character discovery system: characters appear based on your actual work journey, not gacha or purchase
- Companion Log panel, per-session view, weekly report card

**Phase 2 — the intelligence layer** (this commit)

- **Provider Adapter protocol** — `ClaudeCodeAdapter`, `CodexAdapter`, `AiderAdapter`. A registry pattern replaces the hardcoded switch. The UI reads installed providers at runtime; adding a fourth tool is one file.
- **Context-aware Speech Engine** — characters no longer broadcast on a timer. A `WorkContext` snapshot (session length, file churn, error rate, tool in use) drives when and what they say. Every line is injected with real work data. No more fortune-cookie feel.
- **Passive Evolution Engine** — 6 stages (`newborn → familiar → settled → bonded → devoted → eternal`) driven by cumulative companionship days. Animal Crossing philosophy: absence never degrades, money cannot accelerate. Visuals, dialog, and UI all react to evolution stage.
- **Minimal Mode** — hide the floating character, keep the menu bar. For when you need the session manager but not the personality.
- **Library / executable split** — `PixelPalCore` (headless, testable) + `PixelPal` (AppKit shell). Lets the core logic travel into a Team Plan CLI or a future iOS remote without dragging UI along.
- **70 tests across 10 suites** — evolution boundaries, speech edge cases, discovery idempotency, provider parsing, state machine transitions, plus red-team coverage: 8 malicious socket-input variants, concurrent stress, boundary values.

What's deliberately **not** built: a store, a gacha, a streak counter, a shame notification, or anything that punishes absence.

---

## Architecture

```
 ┌────────────────────────────────────────────────────────┐
 │  Any Terminal (Ghostty, iTerm2, Warp, Terminal.app…)   │
 └───────────────────┬────────────────────────────────────┘
                     │ shell hook (zsh, ~50 lines)
                     ▼
 ┌──────────────┐        ┌────────────────────────────────┐
 │ Claude Code  │───────▶│        Unix Domain Socket      │
 │ Codex        │        └───────────────┬────────────────┘
 │ Aider        │  hooks                 │ ProviderEvent
 └──────────────┘                        ▼
                         ┌──────────────────────────────┐
                         │        PixelPalCore          │
                         │  ┌────────────────────────┐  │
                         │  │ ProviderAdapter (x3)   │  │
                         │  │ SessionManager         │  │
                         │  │ StateMachine           │  │
                         │  │ SpeechEngine (ctx)     │  │
                         │  │ EvolutionEngine (days) │  │
                         │  │ ReminderEngine (3-lyr) │  │
                         │  │ DiscoveryManager       │  │
                         │  │ WorkPatternStore       │  │
                         │  │ CloudSync (iCloud+D1)  │  │
                         │  └───────────┬────────────┘  │
                         └──────────────┼───────────────┘
                                        │
                         ┌──────────────▼───────────────┐
                         │           PixelPal           │
                         │  MenuBar · FloatingWindow ·  │
                         │  SpeechBubble · SessionPanel │
                         └──────────────────────────────┘
```

No command content is ever stored or transmitted — only timing metadata and aggregate work patterns. Work data never leaves the device. Character progress optionally syncs via iCloud KV + a thin Cloudflare Workers / D1 backup.

---

## A few engineering decisions worth naming

**Event-driven, not polled.** The app holds zero open file handles on your shell history or agent logs. Everything is a push event over a Unix socket. When PixelPal is not running, there is no trace of it in your work loop.

**Adapters, not forks.** Adding Codex and Aider did not touch Claude Code's path. `ProviderAdapter` is a 30-line protocol with `buildProcess`, `parseOutput`, `supportsNativeRemote`. The SessionManager doesn't know which tool it's running.

**Passive evolution.** No XP bar. No streak counter. The `EvolutionEngine` reads `cumulativeDays`, maps it to a stage, and returns a visual + dialog bundle. The stage is a pure function of time spent, not behavior. You cannot grind. You also cannot lose it.

**Context-aware speech.** The old path was "every 15 minutes, pick a random line from a pool." The new path is "when a `WorkContext` observation crosses a threshold worth speaking about, pick a line that can be templated with the actual data." The difference between a fortune cookie and a friend.

**Red-team what talks to the world.** The socket server has 8 adversarial test cases covering malformed JSON, oversized payloads, injection attempts, and concurrent write races. If it listens on a socket, it gets attacked in tests before shipping.

---

## Install

```bash
git clone https://github.com/vince-ni/PixelPal.git
cd PixelPal
bash Scripts/build.sh
open .build/PixelPal.app
```

Requirements: macOS 14+, Xcode Command Line Tools. Universal Binary (Apple Silicon + Intel).

A signed `.dmg` will be published with the first public release.

---

## Tech stack

- Swift 5.9 + SwiftUI + AppKit (macOS 14+)
- Swift Package Manager, library + executable targets
- Unix domain socket IPC
- `NSImage` with `imageInterpolation = .none` for pixel-crisp rendering
- `swift-testing` for the test suite
- Cloudflare Workers + D1 (optional character backup; work data never goes here)

---

## Project structure

```
Sources/
├── PixelPalCore/               — headless, unit-testable, reusable
│   ├── ProviderAdapter.swift   — adapter protocol
│   ├── ClaudeCodeAdapter.swift
│   ├── CodexAdapter.swift
│   ├── AiderAdapter.swift
│   ├── SessionManager.swift    — AI agent process lifecycle
│   ├── StateMachine.swift      — character state (idle/working/celebrate/nudge/comfort)
│   ├── SpeechEngine.swift      — context-aware trigger
│   ├── SpeechPool.swift        — per-character line pools (CN + EN)
│   ├── EvolutionEngine.swift   — 6-stage passive evolution
│   ├── ReminderEngine.swift    — three-layer scientific breaks
│   ├── DiscoveryManager.swift  — journey-based character unlock
│   ├── WorkPatternStore.swift  — local work data persistence
│   ├── WorkContext.swift       — structured observation snapshot
│   ├── SocketServer.swift      — Unix socket event receiver
│   └── CloudSync.swift         — iCloud KV + D1 sync
├── PixelPal/                   — AppKit shell
│   ├── main.swift              — App entry + MenuBarController
│   ├── Config/AutoConfigurator.swift — zero-config hook injection
│   └── UI/
│       ├── SpriteSheet.swift
│       ├── FloatingCharacterWindow.swift
│       ├── SessionPanelView.swift
│       └── WeeklyReportView.swift
└── …

Tests/PixelPalTests/            — 70 tests, 10 suites
```

---

## Privacy

- All work data stays on your Mac. JSON files under `~/Library/Application Support/PixelPal/`.
- No telemetry, no analytics, no tracking of any kind.
- Character progress optionally syncs via iCloud KV; can be fully disabled.
- No command content is stored — only timing metadata and aggregate patterns.
- Uninstall removes all injected hooks automatically.

---

## Philosophy

A few principles that show up everywhere in the code:

- **95% quiet, 5% personality.** Ambient by default. A companion, not a notification generator.
- **Never punish absence.** Take a week off. Come back. The character is exactly as you left it, and will say something warm.
- **Time, not money.** Evolution is driven by days of companionship. There is no way to pay to skip it.
- **Sprite art is closed.** The code is MIT. The pixel sprites are not in this repo — that's where the visual identity lives. Running from source gives you an SF Symbol fallback; the published builds ship with the art.

---

## Credits

Character art generated with [Pixel Engine](https://pixelengine.ai). Product design, personality system, and interaction philosophy by [Vince Ni](https://github.com/vince-ni).

## License

MIT — see [LICENSE](LICENSE). License applies to code in this repository. Pixel sprite art (under `Assets/`) is not distributed under MIT and is not included in this repo.
